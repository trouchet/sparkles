#!/usr/bin/env bash
# -- Build Apache Spark Standalone Cluster Docker Images

# ----------------------------------------------------------------------------------------------------------------------
# -- Variables ---------------------------------------------------------------------------------------------------------
# ----------------------------------------------------------------------------------------------------------------------

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
BUILD_DATE="$(date -u +'%Y-%m-%d')"

# Description: Read the value of a key from the build configuration file (build.yml).
# Inputs:
#   $1: The path to the build configuration file.
#   $2: The key to search for in the build configuration file.
# Outputs:
#   The value corresponding to the provided key in the build configuration file.
read_config() {
  local file_path="$1"
  local key="$2"
  local value=$(grep -m 1 "$key" "$file_path" | grep -o -P '(?<=").*(?=")')

  if [[ -z "$value" ]]; then
    echo "Error: Required configuration value '$key' is missing in $file_path" >&2
    exit 1
  fi

  echo "$value"
}

# Validate and assign build configuration values
BUILD_CONFIG_FILE="$SCRIPT_DIR/build.yml"                                        # Path to the build configuration file

SHOULD_BUILD_BASE=$(read_config "$BUILD_CONFIG_FILE" "build_base")               # Whether to build the base image
SHOULD_BUILD_SPARK=$(read_config "$BUILD_CONFIG_FILE" "build_spark")             # Whether to build the Spark images
SHOULD_BUILD_JUPYTERLAB=$(read_config "$BUILD_CONFIG_FILE" "build_jupyterlab")   # Whether to build the JupyterLab image

SPARK_VERSION=$(read_config "$BUILD_CONFIG_FILE" "spark")                        # Spark version
JUPYTERLAB_VERSION=$(read_config "$BUILD_CONFIG_FILE" "jupyterlab")              # JupyterLab version
SPARK_VERSION_MAJOR=${SPARK_VERSION:0:1}

# Set Hadoop version and Scala version based on Spark version
if [ "${SPARK_VERSION_MAJOR}" == "2" ]; then
  # For Spark 2.x, use Hadoop 2.7, Scala 2.11, and Scala Kernel 0.6.0.
  HADOOP_VERSION="2.7"
  SCALA_VERSION="2.11.12"
  SCALA_KERNEL_VERSION="0.6.0"
elif [ "${SPARK_VERSION_MAJOR}" == "3" ]; then
  # For Spark 3.x, use Hadoop 3.2, Scala 2.12, and Scala Kernel 0.10.9.
  HADOOP_VERSION="3.2"
  SCALA_VERSION="2.12.10"
  SCALA_KERNEL_VERSION="0.10.9"
else
  # Unsupported Spark version.
  echo "Unsupported Spark version: $SPARK_VERSION"
  exit 1
fi


# ----------------------------------------------------------------------------------------------------------------------
# -- Functions ----------------------------------------------------------------------------------------------------------
# ----------------------------------------------------------------------------------------------------------------------

# Description: Clean up Docker environment
# 
# Inputs: None
# Outputs: None
sanitize() {
  docker system prune --volumes -f

  for image_id in $(docker images --filter "dangling=true" -q --no-trunc); do
    docker rmi "$image_id"
  done
}

# Description: Clean up a specific container
# 
# Inputs:
#   $1: Container name
# Outputs: None
cleanContainer() {
  local container_name="$1"
  echo "Deleting container: $container_name"

  # Loop until all containers with the given name are stopped and removed
  while container=$(docker ps -a -q -f name="$container_name"); [[ -n "$container" ]]; do
    docker stop "$container"  # Stop the container
    docker rm "$container"    # Remove the container
  done
}

# Description: Clean up all containers
# 
# Inputs: None
# Outputs: None
cleanContainers() {
  # Define an array of container names to be cleaned
  local container_names=("jupyterlab" "spark-worker" "spark-master" "spark-base" "base")

  # Loop over each container name and call the cleanContainer function
  for container_name in "${container_names[@]}"; do
    cleanContainer "$container_name"  # Clean the specific container
  done
}

# Description: Delete the specified image and its associated sub-images.
# 
# Input: Image name or reference.
# Output: None.
function cleanImageAndSubimages() {

  echo "Image *$1* deletion"

  image_id=$(docker images --filter=reference="$1" -q)

  if [[ -n "${image_id}" ]]; then
    docker rmi -f "${image_id}"

    subimages=$(docker images --filter=since="$image_id" -q)

    if [[ -n "${subimages}" ]]; then
      docker rmi -f "${subimages}"
    fi
  fi
}

# Description: Delete all relevant images based on the build configuration.
#
# Input: None.
# Output: None.
cleanImages() {

  local container_names=("jupyterlab" "spark-worker" "spark-master" "spark-base")

  for container_name in "${container_names[@]}"; do
    cleanImageAndSubimages "${container_name}"
  done
}

# Description: Clean up a specific Docker volume.
#
# Inputs:
#   $1: Volume name
# Outputs: None
function cleanVolume() {
  local volume_name="$1"
  
  # Check if the volume exists before removing it
  if docker volume ls -q --filter name="$volume_name" | grep -q "$volume_name"; then
    echo "Deleting volume: $volume_name"
    docker volume rm "$volume_name"
  else
    echo "Volume '$volume_name' does not exist. Doing nothing."
  fi
}


# Description: Clean up multiple Docker volumes.
#
# Inputs: None
# Outputs: None
function cleanVolumes() {
  declare -a volume_names=("hadoop-distributed-file-system")
  
  for volume_name in "${volume_names[@]}"; do
    cleanVolume "$volume_name"
  done
}

# Description: Clean the Docker environment by sanitizing resources, cleaning containers, images, and volumes.
#
# Input: None.
# Output: None.
function cleanEnvironment() {  
  # Step 1: Sanitize Docker resources
  sanitize

  # Step 2: Clean up containers
  cleanContainers

  # Step 3: Clean up images
  cleanImages

  # Step 4: Clean up volumes
  cleanVolumes
}

# Description: Build a Docker image with the specified arguments.
#
# Inputs:
#   $1: Dockerfile path
#   $2: Tag name
#   $3: Additional build arguments
# Outputs: None
function buildImage() {
  local dockerfile_path="$1"
  local tag_name="$2"
  local additional_args="$3"
  
  docker build \
    --build-arg build_date="${BUILD_DATE}" \
    ${additional_args} \
    -f "${dockerfile_path}" \
    -t "${tag_name}" \
    -q \
    .
}

# Description: Build the Docker images based on the build configuration.
#
# Inputs: None
# Outputs: None
function buildImages() {
  DOCKER_BASE_DIR="$SCRIPT_DIR/docker"
  
  declare -A image_configs=(
    ["base"]="base:latest \
    --build-arg scala_version=${SCALA_VERSION}"
    ["spark-base"]="spark-base:${SPARK_VERSION} \
    --build-arg spark_version=${SPARK_VERSION} \
    --build-arg hadoop_version=${HADOOP_VERSION}"
    ["spark-master"]="spark-master:${SPARK_VERSION} \
    --build-arg spark_version=${SPARK_VERSION}"
    ["spark-worker"]="spark-worker:${SPARK_VERSION} \
    --build-arg spark_version=${SPARK_VERSION}"
    ["jupyterlab"]="jupyterlab:${JUPYTERLAB_VERSION}-spark-${SPARK_VERSION} \
    --build-arg build_date="${BUILD_DATE}" \
    --build-arg scala_kernel_version="${SCALA_KERNEL_VERSION}" \
    --build-arg scala_version="${SCALA_VERSION}" \
    --build-arg spark_version="${SPARK_VERSION}" \
    --build-arg jupyterlab_version=${JUPYTERLAB_VERSION}"       
  )
  
  for image_name in "${!image_configs[@]}"; do
    read -r tag_name additional_args <<<"${image_configs[$image_name]}"
    buildImage "$DOCKER_BASE_DIR/$image_name/Dockerfile" "$tag_name" "$additional_args"
  done
}

# Description: Builds the Docker images required for the Apache Spark standalone cluster environment.
# 
# Input: None.
# Output: None.
function buildEnvironment() {
  # Build the Docker images based on the build configuration
  buildImages
}

# Description: Prepares the environment by cleaning up any existing containers, images, and volumes,
# and then builds the Docker images required for the Apache Spark standalone cluster environment.
# 
# Input: None.
# Output: None.
function prepareEnvironment() {
  # Clean the Docker environment
  cleanEnvironment

  # Build the required Docker images
  buildEnvironment
}

# ----------------------------------------------------------------------------------------------------------------------
# -- Main --------------------------------------------------------------------------------------------------------------
# ----------------------------------------------------------------------------------------------------------------------

prepareEnvironment