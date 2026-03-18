#!/bin/bash
# this script mimics the ROS pipeline behavior
set -e
# ROS version to compile packages, change to melodic if needed
ROS_DISTRO="humble"

# pipeline behaviour
ROS_BUILDTOOLS_DOCKER_IMAGE="ros-buildtools:${ROS_DISTRO}"
# making sure its in the working directory despite where its being called from.
#SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
#cd "$SCRIPT_DIR"

IN_CONTAINER_MOUNT_POINT="/__w/workspace/src"

container_id=$(docker run -td -v "$(pwd)":$IN_CONTAINER_MOUNT_POINT "$ROS_BUILDTOOLS_DOCKER_IMAGE")

echo "running in $container_id"
docker exec -t "$container_id" bash -c "\
set -e

sudo apt update
python3 -m pip install -i https://artifacts.cloud.mov.ai/repository/pypi-edge/simple --extra-index-url https://pypi.org/simple mobros==2.1.1.6 --ignore-installed
python3 -m pip install mobtest==0.0.2.2 --ignore-installed
mkdir /opt/mov.ai/user/cache/ros/src/
ln -s /__w/workspace/src/* /opt/mov.ai/user/cache/ros/src/

export MOVAI_OUTPUT_DIR=/__w/workspace/src/packages
export PATH=/opt/mov.ai/.local/bin:$PATH

mobtest repo \"/__w/workspace/src\"

ls \"/__w/workspace/src\"

echo '------- Raising packages -------'
mobros raise --workspace="/__w/workspace/src"

echo '------- Installing build dependencies -------'
sudo mobros install-build-dependencies  --workspace="/__w/workspace/src"
echo '------- Building packages -------'
mobros build 
echo '------- Packing packages -------'
mobros pack --workspace="/__w/workspace/src" --mode release 

" || true

echo "removing container: ${container_id}"
docker rm -f "$container_id"

