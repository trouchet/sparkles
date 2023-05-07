# Makefile

NUM_WORKERS ?= 5

.PHONY: all build venv preprocess deploy

all: deploy

build: build/build.sh
	@chmod +x build/build.sh
	@./build/build.sh

venv: venv/bin/activate

venv/bin/activate: requirements.txt
	@echo "Creating virtual environment..."
	@test -d venv || python3 -m venv venv
	@. venv/bin/activate; pip install -r requirements.txt
	@touch venv/bin/activate

preprocess: venv build
	@echo "Preprocessing docker-compose.yml..."
	@. venv/bin/activate; python preprocess.py $(NUM_WORKERS)

deploy: stop-containers preprocess
	@echo "Deploying docker-compose.yml..."
	@docker-compose up -d

stop-containers:
	@echo "Stopping and removing existing containers..."
	@docker-compose down -v --remove-orphans
	@docker volume rm -f hadoop-distributed-file-system
