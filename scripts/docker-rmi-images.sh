#!/bin/bash

# List of image names to remove
images=(
  "base"
  "spark-base"
  "spark-master"
  "spark-worker"
  "jupyterlab"
)

# Restart containers function
rmi_containers() {
  # Iterate over the images and remove them
  for image in "${images[@]}"; do
    
    # Get the image ID
    image_id=$(docker images -q "$image")

    # Check if the image exists
    if [[ -n "$image_id" ]]; then
      # Remove the image
      docker rmi "$image_id"
      echo "Removed image: $image"
    else
      echo "Image not found: $image"
    fi
  done
}

rmi_containers