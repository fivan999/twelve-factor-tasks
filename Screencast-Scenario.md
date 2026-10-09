# Week 2 Screencast Scenario

Целевая длительность записи — 5–7 минут. Перед записью следует один раз выполнить `make minikube-up`, чтобы большие базовые образы уже находились в локальном кэше.

По этому сценарию подготовлен файл `Week-2-Screencast.webm`. Фактическая продолжительность сокращённой демонстрации — 2 минуты 13 секунд.

## 0:00–0:40 — окружение и манифесты

Показать, что используется Podman, а затем кратко вывести список манифестов:

```bash
podman version
minikube version
kubectl version --client
ls deploy/k8s
```

Не показывать содержимое `deploy/k8s/secret.env`.

## 0:40–2:20 — запуск приложения и зависимостей

Повторно применить развёртывание. Скрипт удалит и создаст заново только Job миграции; остальные операции идемпотентны:

```bash
./scripts/k8s-deploy.sh
```

В выводе должны быть видны `kubectl apply`, ожидание PostgreSQL, успешный Job миграции и готовность Deployment приложения.

## 2:20–3:10 — запущенные ресурсы

```bash
kubectl -n focus get pods,services,jobs,persistentvolumeclaims
kubectl -n focus get pods -o wide
```

Кратко пояснить назначение Deployment, Pod, Service, Job и PersistentVolumeClaim.

## 3:10–4:20 — масштабирование

```bash
kubectl -n focus scale deployment/focus --replicas=3
kubectl -n focus rollout status deployment/focus --timeout=180s
kubectl -n focus get pods -l app.kubernetes.io/name=focus -o wide
```

Показать три Pod приложения в состоянии `Running` и `Ready`.

## 4:20–6:30 — проверка UI

В первом терминале получить адрес:

```bash
minikube service focus -n focus --url
```

Открыть выданный URL в браузере и выполнить несколько действий:

1. создать задачу;
2. отметить её выполненной;
3. изменить название или описание;
4. обновить страницу и показать, что данные сохранились;
5. удалить задачу.

## 6:30–7:00 — итог

Вернуться в терминал и показать итоговое состояние:

```bash
kubectl -n focus get deployment focus
kubectl -n focus get pods
```

Завершить пояснением: Service балансирует запросы между тремя stateless-репликами Go-приложения, а общее состояние хранится в PostgreSQL на PersistentVolume.
