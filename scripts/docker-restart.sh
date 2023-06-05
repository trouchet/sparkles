#!/bin/bash

# List of image names to remove
images=(
  "jupyterlab"
  "spark-worker"
  "spark-master"
  "spark-base"
  "base"
)

# Restart containers function
restart_containers() {
  # Start the containers based on the image names
  for image in "${images[@]}"; do
    # Check if the container is running
    container_ids=$(docker ps -a --filter "ancestor=$image" --format '{{.ID}}')
    if [[ -n "$container_ids" ]]; then
      # Restart the containers
      for container_id in $container_ids; do
        docker restart "$container_id"
        echo "Restarted container: $container_id (based on image: $image)"
      done
    else
      echo "No container found based on image: $image"
    fi
  done
}

restart_containers
