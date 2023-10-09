# Makefile

# Set the default number of workers to 5 if not provided
NUM_WORKERS ?= 5


.PHONY: all build venv preprocess deploy

# Default target: deploy
all: deploy

# Target: build
# Runs the build script
build: build/build.sh
	@chmod +x build/build.sh
	@./build/build.sh

# Target: venv
# Creates a virtual environment and installs dependencies
venv: venv/bin/activate

venv/bin/activate: requirements.txt
	@echo "Creating virtual environment..."
	@test -d venv || python3 -m venv venv
	@. venv/bin/activate; pip install -r requirements.txt
	@touch venv/bin/activate

# Target: preprocess
# Runs the preprocess script using the virtual environment and the specified number of workers
preprocess: venv build
	@echo "Preprocessing docker-compose.yml..."
	@. venv/bin/activate; python preprocess.py $(NUM_WORKERS)

# Target: push
# push existing containers to Docker Hub
push: 
	./scripts/docker-push.sh $(u)

# Target: stop
# Stops and removes existing containers, and removes the HDFS volume
stop:
	@echo "Stopping and removing existing containers..."
	@docker-compose down -v --remove-orphans
	@docker volume rm -f hadoop-distributed-file-system


# Target: deploy
# Stops existing containers, preprocesses the docker-compose.yml, and deploys the containers
deploy: stop preprocess build
	@echo "Deploying docker-compose.yml..."
	@docker-compose build --no-cache
	@docker-compose up -d


# Target: scale-up
# Scale up the number of containers or workers
scale-up: venv
	@echo "Scaling up..."
	@NUM_WORKERS=$$(($(NUM_WORKERS) + 1)); \
	make stop; \
	make preprocess; \
	docker-compose build --no-cache; \
	docker-compose up -d

# Target: ps
# List spark-container information 
ps:
	@echo "Listing spark-related containers..."
	@docker ps --filter "name=spark" --filter "name=jupyterlab"
	
# Target: logs
# Display the logs of running containers
logs:
	@echo "Displaying logs..."
	@docker-compose logs
