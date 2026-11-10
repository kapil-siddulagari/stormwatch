COMPOSE = docker compose -f infra/docker/compose.yaml

help:           ## List available commands
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'
up:             ## Postgres + Redis
	$(COMPOSE) --profile core up -d
up-auth:        ## add Keycloak
	$(COMPOSE) --profile core --profile auth up -d
down:           ## Stop all containers
	$(COMPOSE) --profile "*" down
logs:           ## Follow logs
	$(COMPOSE) logs -f
ps:             ## List containers
	$(COMPOSE) ps
run-ingestion:  ## Run ingestion service
	./mvnw -pl services/ingestion-service spring-boot:run
run-api:        ## Run alert API service
	./mvnw -pl services/alert-api spring-boot:run
reset-db:       ## Stop everything and DELETE all local data
	$(COMPOSE) --profile "*" down -v

.PHONY: up up-auth down logs ps run-ingestion run-api reset-db help
