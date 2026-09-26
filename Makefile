IMAGE := localhost/twelve-factor-tasks:dev
NETWORK := twelve-factor-tasks-net
DB_CONTAINER := twelve-factor-tasks-db
APP_CONTAINER := twelve-factor-tasks-app
VOLUME := twelve-factor-tasks-data
DATABASE_URL := postgres://tasks:tasks@$(DB_CONTAINER):5432/tasks?sslmode=disable

.PHONY: build network db wait-db migrate app up down logs test

build:
	podman build -t $(IMAGE) -f Containerfile .

network:
	@podman network inspect $(NETWORK) >/dev/null 2>&1 || podman network create $(NETWORK)

db: network
	@podman volume inspect $(VOLUME) >/dev/null 2>&1 || podman volume create $(VOLUME)
	podman run -d --replace --name $(DB_CONTAINER) --network $(NETWORK) \
		-e POSTGRES_USER=tasks -e POSTGRES_PASSWORD=tasks -e POSTGRES_DB=tasks \
		-v $(VOLUME):/var/lib/postgresql/data docker.io/library/postgres:17-alpine

wait-db:
	@echo "Waiting for PostgreSQL..."
	@until podman exec $(DB_CONTAINER) pg_isready -U tasks -d tasks >/dev/null 2>&1; do sleep 1; done

migrate:
	podman run --rm --network $(NETWORK) -e 'DATABASE_URL=$(DATABASE_URL)' \
		--entrypoint /app/migrate $(IMAGE)

app:
	podman run -d --replace --name $(APP_CONTAINER) --network $(NETWORK) \
		-p 8080:8080 -e PORT=8080 -e 'DATABASE_URL=$(DATABASE_URL)' \
		-e SHUTDOWN_TIMEOUT=10s $(IMAGE)

up: build db wait-db migrate app
	@echo "Task tracker is running at http://localhost:8080"

down:
	-podman rm -f $(APP_CONTAINER) $(DB_CONTAINER)
	@echo "Containers stopped. The database volume is preserved."

logs:
	podman logs -f $(APP_CONTAINER)

test:
	podman build --target build -t $(IMAGE)-test -f Containerfile .

