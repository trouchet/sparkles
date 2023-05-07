# Enable Docker BuildKit
# This enables the use of the ARG instruction for relative path resolution
# You can remove this line if you already have it enabled in your Docker daemon configuration
# See: https://docs.docker.com/develop/develop-images/build_enhancements/
# syntax = docker/dockerfile:experimental

FROM base
LABEL maintainer="Bruno Peixoto <brunolnetto@gmail.com>"

# -- Layer: Image Metadata

ARG build_date

LABEL org.label-schema.build-date=${build_date}
LABEL org.label-schema.name="Apache Spark Standalone Cluster on Docker - JupyterLab Image"
LABEL org.label-schema.description="JupyterLab image"
LABEL org.label-schema.url="https://github.com/andre-marcos-perez/spark-cluster-on-docker"
LABEL org.label-schema.schema-version="1.0"

# -- Layer: Notebooks and data

RUN mkdir -p ${SHARED_WORKSPACE}

# -- Layer: JupyterLab + Python kernel for PySpark

ARG spark_version
ARG jupyterlab_version
ARG scala_kernel_version

RUN apt-get update -y && \
    apt-get install -y python3-pip python3-dev && \
    pip3 install --upgrade pip && \
    pip3 install wget==3.2 pyspark==${spark_version} jupyterlab==${jupyterlab_version}

# -- Layer: Scala kernel for Spark

ARG scala_version

RUN apt-get install -y ca-certificates-java --no-install-recommends && \
    curl -Lo coursier https://git.io/coursier-cli && \
    chmod +x coursier && \
    ./coursier launch --fork almond:${scala_kernel_version} --scala ${scala_version} -- --display-name "Scala ${scala_version}" --install && \
    rm -f coursier

# -- Layer: R kernel for SparkR

RUN apt-get install -y r-base-dev && \
    R -e "install.packages('IRkernel')" && \
    R -e "IRkernel::installspec(displayname = 'R 3.5', user = FALSE)" && \
    curl https://archive.apache.org/dist/spark/spark-${spark_version}/SparkR_${spark_version}.tar.gz -k -o sparkr.tar.gz && \
    R CMD INSTALL sparkr.tar.gz && \
    rm -f sparkr.tar.gz

# -- Layer: Copy local workspace

# Obtain the relative path to the workspace folder
ARG WORKSPACE_RELATIVE_PATH=build/workspace

# Copy the workspace folder to the shared workspace location
COPY $WORKSPACE_RELATIVE_PATH /opt/workspace/

# -- Runtime

EXPOSE 8888

WORKDIR ${SHARED_WORKSPACE}
CMD jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token=
