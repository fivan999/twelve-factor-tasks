# Week 2 Report: развёртывание Focus в Kubernetes

## 1. Цель работы

Приложение «Focus» развёрнуто в одноузловом локальном кластере Kubernetes, созданном Minikube. Для сборки OCI-образа и работы драйвера Minikube используется Podman. Docker и Docker daemon не требуются.

В состав развёртывания входят Go-приложение, PostgreSQL и отдельный процесс миграции схемы. Kubernetes-манифесты находятся в каталоге `deploy/k8s`, а воспроизводимые команды запуска — в каталоге `scripts` и `Makefile`.

## 2. Сборка и загрузка образа

Приложение собирается multi-stage-файлом `Containerfile`. На build-стадии выполняются тесты и компилируются бинарники `/app/server` и `/app/migrate`. Runtime-стадия содержит только необходимые сертификаты, часовые пояса и два бинарника; процесс запускается непривилегированным пользователем `app`.

Скрипт `scripts/minikube-build.sh` выполняет три операции:

1. `podman build` создаёт локальный образ `localhost/twelve-factor-tasks:week2`.
2. `podman save --format oci-archive` сохраняет образ как OCI-архив.
3. `minikube image load` загружает архив в container runtime узла Minikube.

В Deployment и Job задано `imagePullPolicy: Never`. Поэтому Kubernetes использует загруженный локальный образ и не пытается получить его из внешнего registry.

## 3. Использованные абстракции Kubernetes

### Namespace

`Namespace focus` изолирует ресурсы приложения от системных компонентов кластера и позволяет выполнять команды с единым параметром `-n focus`.

### ConfigMap

`ConfigMap focus-config` хранит несекретную конфигурацию: `PORT` и `SHUTDOWN_TIMEOUT`. Значения передаются контейнеру как переменные окружения.

### Secret

`Secret focus-secrets` содержит реквизиты PostgreSQL и `DATABASE_URL`. Он создаётся скриптом из локального файла `deploy/k8s/secret.env`, который исключён из Git. В репозитории находится только безопасный шаблон `secret.env.example`.

### Deployment

`Deployment focus` управляет stateless-репликами Go-сервера. Он поддерживает требуемое число Pod, выполняет rolling update и позволяет масштабировать сервер одной командой `kubectl scale`.

`Deployment postgres` запускает один экземпляр PostgreSQL. Стратегия `Recreate` не допускает одновременную работу двух Pod с одним локальным томом ReadWriteOnce.

### Service

`Service postgres` типа `ClusterIP` создаёт стабильное внутреннее DNS-имя `postgres.focus.svc.cluster.local`. По нему Go-приложение и мигратор подключаются к БД, даже если Pod PostgreSQL был пересоздан и получил другой IP-адрес.

`Service focus` типа `NodePort` распределяет HTTP-запросы между готовыми репликами приложения. Для локального доступа URL выдаёт команда `minikube service focus -n focus --url`.

### Job

`Job focus-migrate` запускает `/app/migrate` как одноразовый административный процесс. Развёртывающий скрипт ожидает успешного завершения Job и только после этого применяет Deployment приложения. Такое разделение сохраняет стадии build, release и run.

### PersistentVolumeClaim

`PersistentVolumeClaim postgres-data` запрашивает 1 GiB постоянного хранилища. Данные PostgreSQL не находятся в файловой системе Pod и сохраняются при его пересоздании. В Minikube подходящий PersistentVolume выделяется стандартным provisioner кластера.

### Readiness и liveness probes

Readiness probe приложения обращается к `/healthz`, который проверяет связь с PostgreSQL. Service не направляет трафик в Pod, пока приложение и БД не готовы. Liveness probe обращается к `/` и позволяет Kubernetes перезапустить зависший HTTP-процесс.

У PostgreSQL readiness и liveness probes выполняют `pg_isready`. Для всех рабочих контейнеров заданы requests и limits CPU и памяти.

## 4. Взаимодействие компонентов

```text
Браузер
   │ HTTP
   ▼
Service focus (NodePort)
   │ балансировка по готовым Pod
   ├──────────────┬──────────────┐
   ▼              ▼              ▼
Pod focus-1    Pod focus-2    Pod focus-3
   │              │              │
   └──────────────┴──────┬───────┘
                         │ PostgreSQL protocol
                         ▼
               Service postgres (ClusterIP)
                         │
                         ▼
                    Pod postgres
                         │
                         ▼
                  PVC postgres-data

Job focus-migrate ── PostgreSQL protocol ──► Service postgres
```

Фронтенд встроен в Go-бинарник, поэтому отдельный frontend Pod и дополнительный Service не нужны. Браузер получает HTML, CSS и JavaScript от того же HTTP-сервера, а JavaScript вызывает REST API `/api/tasks` на том же origin. Любая реплика приложения может обработать запрос, поскольку пользовательское состояние хранится в общей PostgreSQL.

## 5. Порядок запуска

На macOS Podman driver Minikube запускается через rootful Podman Machine. Чтобы не менять существующую rootless-машину, можно создать отдельную:

```bash
podman machine init --rootful --cpus 4 --memory 6144 minikube-podman
podman machine start minikube-podman
podman system connection default minikube-podman-root
```

После этого нужно создать локальную конфигурацию секрета:

```bash
cp deploy/k8s/secret.env.example deploy/k8s/secret.env
```

В `deploy/k8s/secret.env` необходимо заменить оба значения `change-me` одним учебным паролем. Полный запуск выполняется командой:

```bash
make minikube-up
```

Команда последовательно:

1. запускает Minikube с Podman driver и CRI-O;
2. собирает образ через Podman;
3. загружает образ в Minikube;
4. создаёт Namespace и Secret;
5. запускает PostgreSQL и ожидает readiness;
6. запускает Job миграции и ожидает его завершения;
7. запускает Go-приложение и выводит состояние ресурсов.

## 6. Проверка и масштабирование

Проверка выполнена в Minikube 1.39.0 с Kubernetes 1.37.0 и CRI-O 1.35.7 поверх Podman 5.8.3. После применения манифестов PostgreSQL и приложение перешли в состояние `Running`, PVC — в `Bound`, а Job миграции завершился со статусом `Complete`.

Состояние ресурсов:

```bash
make k8s-status
```

Масштабирование HTTP-сервера до трёх реплик:

```bash
make k8s-scale
kubectl -n focus get pods -l app.kubernetes.io/name=focus -o wide
```

Получение URL приложения:

```bash
make k8s-url
```

В UI проверяются создание, чтение, изменение статуса, редактирование и удаление задачи. Масштабирование не приводит к потере данных: все реплики используют один Service PostgreSQL и постоянный том БД.

При фактической проверке Deployment был масштабирован до трёх готовых Pod. Через локальный port-forward последовательно выполнены `POST`, `GET`, `PUT` и `DELETE` для `/api/tasks`; после удаления API вернул пустой список. Тем самым проверены балансировка через Service, доступ всех реплик к общей БД и полный CRUD-сценарий.

## 7. Состав манифестов

| Файл | Назначение |
|---|---|
| `deploy/k8s/00-namespace.yaml` | Namespace приложения |
| `deploy/k8s/01-config.yaml` | несекретная конфигурация |
| `deploy/k8s/02-postgres.yaml` | PVC, Deployment и Service PostgreSQL |
| `deploy/k8s/03-migration-job.yaml` | одноразовая миграция схемы |
| `deploy/k8s/04-app.yaml` | Deployment и NodePort Service приложения |
| `deploy/k8s/secret.env.example` | шаблон локальных секретов |

## 8. Скринкаст

Скринкаст находится в файле `Week-2-Screencast.webm`. Продолжительность — 2 минуты 13 секунд, разрешение — 800×450. Видео включает проверку окружения, применение манифестов, вывод запущенных Pod, Service, Job и PVC, масштабирование Deployment до трёх реплик, схему взаимодействия компонентов и полный CRUD-сценарий через настоящий UI приложения.

Видео записано без звуковой дорожки. Действия сопровождаются экранными заголовками и пояснениями. Сценарий записи находится в `Screencast-Scenario.md`.

## 9. Итог

Подготовлено воспроизводимое одноузловое развёртывание приложения в Kubernetes. Сборка выполняется Podman, локальный образ явно загружается в Minikube, конфигурация отделена от образа, миграция выполняется отдельным Job, сервер масштабируется независимо от PostgreSQL, а данные БД размещаются в PersistentVolume.
