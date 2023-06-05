#!/bin/bash

# Step 1: Get the container IDs of the desired containers
container_ids=$(docker ps -a \
--filter "name=spark" \
--filter "name=jupyterlab" \
--format "{{.ID}}")

# Step 2: Create a consolidated image
consolidated_image="sparkles"
for container_id in $container_ids; do
    docker commit "$container_id" "$consolidated_image"
done

# Step 3: Login to DockerHub
docker login

# Step 4: Tag the consolidated image
docker tag "$consolidated_image" "$1/$consolidated_image"

# Step 5: Push the consolidated image to DockerHub
docker push "$1/$consolidated_image"
