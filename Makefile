# Makefile for Todo App Server Docker Operations
# Usage: make [target]

# Default compose file
COMPOSE_FILE := docker-compose.yml
PROJECT_NAME := todo_app_server

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m # No Color

.PHONY: help build up down restart logs shell exec clean ps status health install migrate seed console test lint format backup restore

# Default target
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo "$(GREEN)Todo App Server - Docker Operations$(NC)"
	@echo ""
	@echo "$(YELLOW)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make up          # Start all services"
	@echo "  make logs        # View logs for all services"
	@echo "  make shell       # Enter the app container shell"
	@echo "  make migrate     # Run database migrations"

# Build and Run Operations
build: ## Build all Docker images
	@echo "$(YELLOW)Building Docker images...$(NC)"
	docker compose -f $(COMPOSE_FILE) build

up: ## Start all services in background
	@echo "$(YELLOW)Starting services...$(NC)"
	docker compose -f $(COMPOSE_FILE) up -d
	@echo "$(GREEN)Services started. Use 'make logs' to view output.$(NC)"

up-build: ## Build and start all services
	@echo "$(YELLOW)Building and starting services...$(NC)"
	docker compose -f $(COMPOSE_FILE) up -d --build

down: ## Stop and remove all containers
	@echo "$(YELLOW)Stopping services...$(NC)"
	docker compose -f $(COMPOSE_FILE) down
	@echo "$(GREEN)Services stopped.$(NC)"

restart: ## Restart all services
	@echo "$(YELLOW)Restarting services...$(NC)"
	docker compose -f $(COMPOSE_FILE) restart
	@echo "$(GREEN)Services restarted.$(NC)"

# Logging and Monitoring
logs: ## View logs for all services
	docker compose -f $(COMPOSE_FILE) logs -f

logs-app: ## View logs for app service only
	docker compose -f $(COMPOSE_FILE) logs -f app

logs-db: ## View logs for database service only
	docker compose -f $(COMPOSE_FILE) logs -f db

logs-redis: ## View logs for Redis service only
	docker compose -f $(COMPOSE_FILE) logs -f redis

ps: ## Show running containers
	docker compose -f $(COMPOSE_FILE) ps

status: ## Show detailed status of all services
	@echo "$(YELLOW)Container Status:$(NC)"
	@docker compose -f $(COMPOSE_FILE) ps --format "table {{.Name}}\t{{.Command}}\t{{.State}}\t{{.Ports}}"

health: ## Check health of all services
	@echo "$(YELLOW)Health Check:$(NC)"
	@docker compose -f $(COMPOSE_FILE) ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}"

# Container Access
shell: ## Enter app container shell
	@echo "$(YELLOW)Entering app container shell...$(NC)"
	docker compose -f $(COMPOSE_FILE) exec app bash

bash: ## Enter app container shell
	@echo "$(YELLOW)Entering app container bash...$(NC)"
	docker exec -it app bash

bashcid: ## Enter app container using resolved container ID (docker exec -it <container_id> bash)
	@cid=$$(docker compose -f $(COMPOSE_FILE) ps -q app); \
	if [ -z "$$cid" ]; then \
	  echo "$(RED)App container not running. Start services with 'make up'.$(NC)"; \
	  exit 1; \
	fi; \
	echo "$(YELLOW)Opening bash in container $$cid ...$(NC)"; \
	docker exec -it $$cid bash

shell-db: ## Enter database container shell
	@echo "$(YELLOW)Entering database container shell...$(NC)"
	docker compose -f $(COMPOSE_FILE) exec db bash

shell-redis: ## Enter Redis container shell
	@echo "$(YELLOW)Entering Redis container shell...$(NC)"
	docker compose -f $(COMPOSE_FILE) exec redis sh

exec: ## Execute command in app container (usage: make exec CMD="rails -v")
	@if [ -z "$(CMD)" ]; then \
		echo "$(RED)Error: Please specify CMD. Example: make exec CMD='rails -v'$(NC)"; \
		exit 1; \
	fi
	docker compose -f $(COMPOSE_FILE) exec app $(CMD)


# Database Operations
migrate: ## Run database migrations
	@echo "$(YELLOW)Running database migrations...$(NC)"
	docker compose -f $(COMPOSE_FILE) exec app rails db:migrate
	@echo "$(GREEN)Migrations completed.$(NC)"

migrate-reset: ## Reset database and run migrations
	@echo "$(YELLOW)Resetting database...$(NC)"
	docker compose -f $(COMPOSE_FILE) exec app rails db:drop db:create db:migrate
	@echo "$(GREEN)Database reset completed.$(NC)"

seed: ## Seed database with sample data
	@echo "$(YELLOW)Seeding database...$(NC)"
	docker compose -f $(COMPOSE_FILE) exec app rails db:seed
	@echo "$(GREEN)Database seeded.$(NC)"

setup: ## Setup database (create, migrate, seed)
	@echo "$(YELLOW)Setting up database...$(NC)"
	docker compose -f $(COMPOSE_FILE) exec app rails db:setup
	@echo "$(GREEN)Database setup completed.$(NC)"

# Rails Operations
console: ## Open Rails console
	@echo "$(YELLOW)Opening Rails console...$(NC)"
	docker compose -f $(COMPOSE_FILE) exec app rails console

routes: ## Show Rails routes
	@echo "$(YELLOW)Rails Routes:$(NC)"
	docker compose -f $(COMPOSE_FILE) exec app rails routes

# Development Tools
install: ## Install/update gems
	@echo "$(YELLOW)Installing gems...$(NC)"
	docker compose -f $(COMPOSE_FILE) exec app bundle install
	@echo "$(GREEN)Gems installed.$(NC)"

test: ## Run tests
	@echo "$(YELLOW)Running tests...$(NC)"
	docker compose -f $(COMPOSE_FILE) exec app rails test

lint: ## Run linter (if configured)
	@echo "$(YELLOW)Running linter...$(NC)"
	docker compose -f $(COMPOSE_FILE) exec app bundle exec rubocop

format: ## Auto-format code (if configured)
	@echo "$(YELLOW)Formatting code...$(NC)"
	docker compose -f $(COMPOSE_FILE) exec app bundle exec rubocop -A

# Cleanup Operations
clean: ## Remove stopped containers and unused images
	@echo "$(YELLOW)Cleaning up Docker resources...$(NC)"
	docker compose -f $(COMPOSE_FILE) down --remove-orphans
	docker system prune -f
	@echo "$(GREEN)Cleanup completed.$(NC)"

clean-all: ## Remove all containers, images, and volumes (DESTRUCTIVE)
	@echo "$(RED)WARNING: This will remove all containers, images, and volumes!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo ""; \
		echo "$(YELLOW)Removing all Docker resources...$(NC)"; \
		docker compose -f $(COMPOSE_FILE) down -v --remove-orphans; \
		docker system prune -af --volumes; \
		echo "$(GREEN)All resources removed.$(NC)"; \
	else \
		echo ""; \
		echo "$(GREEN)Operation cancelled.$(NC)"; \
	fi

# Backup and Restore
backup: ## Backup database
	@echo "$(YELLOW)Creating database backup...$(NC)"
	@mkdir -p backups
	@TIMESTAMP=$$(date +%Y%m%d_%H%M%S); \
	docker compose -f $(COMPOSE_FILE) exec -T db mysqldump -u root -p$$MYSQL_ROOT_PASSWORD $$MYSQL_DATABASE > backups/backup_$$TIMESTAMP.sql; \
	echo "$(GREEN)Backup created: backups/backup_$$TIMESTAMP.sql$(NC)"

restore: ## Restore database (usage: make restore BACKUP=backup_20231201_120000.sql)
	@if [ -z "$(BACKUP)" ]; then \
		echo "$(RED)Error: Please specify BACKUP file. Example: make restore BACKUP=backup_20231201_120000.sql$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f "backups/$(BACKUP)" ]; then \
		echo "$(RED)Error: Backup file backups/$(BACKUP) not found$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Restoring database from backups/$(BACKUP)...$(NC)"
	docker compose -f $(COMPOSE_FILE) exec -T db mysql -u root -p$$MYSQL_ROOT_PASSWORD $$MYSQL_DATABASE < backups/$(BACKUP)
	@echo "$(GREEN)Database restored from backups/$(BACKUP)$(NC)"

# Production Operations
prod-build: ## Build production image
	@echo "$(YELLOW)Building production image...$(NC)"
	docker build -f devops/production/Dockerfile -t todo_app_server:latest .
	@echo "$(GREEN)Production image built.$(NC)"

prod-push: ## Push to registry (set REGISTRY variable)
	@if [ -z "$(REGISTRY)" ]; then \
		echo "$(RED)Error: Please set REGISTRY variable. Example: make prod-push REGISTRY=your-registry.com/todo_app_server$(NC)"; \
		exit 1; \
	fi
	docker tag todo_app_server:latest $(REGISTRY):latest
	docker push $(REGISTRY):latest
	@echo "$(GREEN)Image pushed to $(REGISTRY):latest$(NC)"

# Quick Development Commands
dev: up logs ## Start development environment and show logs
dev-fresh: down build up logs ## Fresh development start (rebuild everything)
dev-reset: down clean build setup up ## Complete reset and fresh start

# Info Commands
info: ## Show project information
	@echo "$(GREEN)Todo App Server - Project Information$(NC)"
	@echo "Project Name: $(PROJECT_NAME)"
	@echo "Compose File: $(COMPOSE_FILE)"
	@echo "Docker Version: $$(docker --version)"
	@echo "Docker Compose Version: $$(docker compose --version)"
	@echo ""
	@echo "$(YELLOW)Current Status:$(NC)"
	@make status

env: ## Show environment variables
	@echo "$(YELLOW)Environment Variables:$(NC)"
	docker compose -f $(COMPOSE_FILE) config