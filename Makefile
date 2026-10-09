IMAGE := localhost/twelve-factor-tasks:dev
NETWORK := twelve-factor-tasks-net
DB_CONTAINER := twelve-factor-tasks-db
APP_CONTAINER := twelve-factor-tasks-app
VOLUME := twelve-factor-tasks-data
ENV_FILE ?= .env

-include $(ENV_FILE)

.PHONY: check-env build network db wait-db migrate app up down logs test minikube-up k8s-status k8s-scale k8s-url

check-env:
	@test -f "$(ENV_FILE)" || (echo "Missing $(ENV_FILE). Copy .env.example to $(ENV_FILE) and set local credentials."; exit 1)
	@test -n "$(PORT)" || (echo "PORT is required in $(ENV_FILE)."; exit 1)
	@test -n "$(DATABASE_URL)" || (echo "DATABASE_URL is required in $(ENV_FILE)."; exit 1)
	@test -n "$(POSTGRES_USER)" || (echo "POSTGRES_USER is required in $(ENV_FILE)."; exit 1)
	@test -n "$(POSTGRES_PASSWORD)" || (echo "POSTGRES_PASSWORD is required in $(ENV_FILE)."; exit 1)
	@test -n "$(POSTGRES_DB)" || (echo "POSTGRES_DB is required in $(ENV_FILE)."; exit 1)

build:
	podman build -t $(IMAGE) -f Containerfile .

network:
	@podman network inspect $(NETWORK) >/dev/null 2>&1 || podman network create $(NETWORK)

db: check-env network
	@podman volume inspect $(VOLUME) >/dev/null 2>&1 || podman volume create $(VOLUME)
	podman run -d --replace --name $(DB_CONTAINER) --network $(NETWORK) --network-alias db \
		--env-file $(ENV_FILE) \
		-v $(VOLUME):/var/lib/postgresql/data docker.io/library/postgres:17-alpine

wait-db: check-env
	@echo "Waiting for PostgreSQL..."
	@until podman exec $(DB_CONTAINER) pg_isready -U $(POSTGRES_USER) -d $(POSTGRES_DB) >/dev/null 2>&1; do sleep 1; done

migrate: check-env network
	podman run --rm --network $(NETWORK) --env-file $(ENV_FILE) \
		--entrypoint /app/migrate $(IMAGE)

app: check-env network
	podman run -d --replace --name $(APP_CONTAINER) --network $(NETWORK) \
		-p $(PORT):$(PORT) --env-file $(ENV_FILE) $(IMAGE)

up: build db wait-db migrate app
	@echo "Task tracker is running at http://localhost:$(PORT)"

down:
	-podman rm -f $(APP_CONTAINER) $(DB_CONTAINER)
	@echo "Containers stopped. The database volume is preserved."

logs:
	podman logs -f $(APP_CONTAINER)

test:
	podman build --target build -t $(IMAGE)-test -f Containerfile .

minikube-up:
	./scripts/minikube-up.sh

k8s-status:
	kubectl -n focus get pods,services,jobs,persistentvolumeclaims

k8s-scale:
	kubectl -n focus scale deployment/focus --replicas=3
	kubectl -n focus rollout status deployment/focus --timeout=180s

k8s-url:
	minikube service focus -n focus --url
