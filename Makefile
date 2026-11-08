COMPOSE = docker compose -f infra/docker/compose.yaml

up:          ## Postgres + Redis
	$(COMPOSE) --profile core up -d
up-auth:     ## add Keycloak
	$(COMPOSE) --profile core --profile auth up -d
down:
	$(COMPOSE) --profile "*" down
logs:
	$(COMPOSE) logs -f
ps:
	$(COMPOSE) ps
run-ingestion:
	./mvnw -pl services/ingestion-service spring-boot:run
run-api:
	./mvnw -pl services/alert-api spring-boot:run
help:   ## List available commands
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'
.PHONY: up up-auth down logs ps run-ingestion run-api help