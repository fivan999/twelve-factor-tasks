# Focus: минимальный task tracker на Go

Небольшое full-stack приложение для управления задачами. Фронтенд написан без фреймворков и встраивается в Go-бинарник, бэкенд предоставляет REST API, данные хранятся в PostgreSQL.

## Быстрый запуск через Podman

Нужны `podman` и `make`. Создайте локальный файл конфигурации:

```bash
cp .env.example .env
```

Файл `.env` не попадает в Git. После настройки запустите приложение:

```bash
make up
```

Откройте <http://localhost:8080>. Остановить приложение:

```bash
make down
```

Данные останутся в Podman volume `twelve-factor-tasks-data`. Удалить их при необходимости можно отдельной явной командой:

```bash
podman volume rm twelve-factor-tasks-data
```

Если установлен compose-провайдер для Podman, альтернативный запуск:

```bash
podman compose up --build
```

`PORT`, `DATABASE_URL`, `POSTGRES_USER`, `POSTGRES_PASSWORD` и `POSTGRES_DB` обязательны. `SHUTDOWN_TIMEOUT` по умолчанию равен `10s`. Значения из `.env.example` предназначены только для локальной разработки. В production передавайте реквизиты PostgreSQL через менеджер секретов среды выполнения.

Перед первым запуском замените `change-me` в `POSTGRES_PASSWORD` и в `DATABASE_URL` на одно и то же локальное значение. Если volume PostgreSQL уже создан, изменение переменной не меняет пароль в существующей базе: используйте прежнее значение или создайте новый volume, если данные больше не нужны.

## CRUD API

| Метод | Путь | Действие |
|---|---|---|
| `GET` | `/api/tasks` | Получить все задачи |
| `POST` | `/api/tasks` | Создать задачу |
| `PUT` | `/api/tasks/{id}` | Полностью обновить задачу |
| `DELETE` | `/api/tasks/{id}` | Удалить задачу |
| `GET` | `/healthz` | Проверить приложение и БД |

Тело создания/обновления:

```json
{
  "title": "Разобраться с Go",
  "description": "Пройти CRUD и context",
  "completed": false
}
```

## Устройство

```text
cmd/server              HTTP-сервер и управление жизненным циклом
cmd/migrate             одноразовый административный процесс
internal/config         конфигурация из переменных окружения
internal/database       подключение к PostgreSQL и миграции
internal/tasks          модель, SQL-репозиторий и HTTP API
internal/webui/assets   фронтенд, встроенный через go:embed
```

Сервер миграции автоматически не запускает: это отдельная стадия release. В `make up` порядок такой: build → PostgreSQL → migrate → app.

## Соответствие 12-factor

1. **Codebase** — один репозиторий, конфигурация деплоя лежит рядом с кодом.
2. **Dependencies** — Go-зависимости объявлены в `go.mod`, окружение изолировано контейнером.
3. **Config** — `PORT`, `DATABASE_URL`, `SHUTDOWN_TIMEOUT` читаются из environment; `PORT` и `DATABASE_URL` обязательны, секреты не зашиты в бинарник.
4. **Backing services** — PostgreSQL подключается только через `DATABASE_URL` и может быть заменён внешним экземпляром.
5. **Build, release, run** — `Containerfile` создаёт артефакт, мигратор оформлен отдельной release-стадией, сервер только запускает приложение.
6. **Processes** — HTTP-сервер stateless; состояние находится в PostgreSQL.
7. **Port binding** — приложение самостоятельно слушает порт из `PORT`.
8. **Concurrency** — можно запускать несколько одинаковых app-контейнеров за балансировщиком.
9. **Disposability** — быстрый старт, обработка SIGINT/SIGTERM и graceful shutdown.
10. **Dev/prod parity** — локально и в production используется тот же OCI-образ и PostgreSQL.
11. **Logs** — структурированные JSON-события выводятся в stdout, файлы логов не создаются.
12. **Admin processes** — миграции запускаются одноразовой командой `/app/migrate`.

## Запуск без контейнера приложения

Если Go установлен локально, поднимите PostgreSQL и экспортируйте `PORT`, `DATABASE_URL` и при необходимости `SHUTDOWN_TIMEOUT`. В `DATABASE_URL` укажите доступный с хоста адрес PostgreSQL, например `localhost`, а не имя контейнера `db`. Затем выполните:

```bash
go run ./cmd/migrate
go run ./cmd/server
```
