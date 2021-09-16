set -e

if [ -z "${IN_CONTAINER_MOUNT_POINT}" ];
then
    printf "ERROR. Please specify the location of the workspace in the env IN_CONTAINER_MOUNT_POINT! \n"
    exit 1
else
    if [ ! -d "${IN_CONTAINER_MOUNT_POINT}" ];
    then
        printf "ERROR. IN_CONTAINER_MOUNT_POINT value is pointing to a non existent folder! \n"
        exit 2
    fi
fi

IN_CONTAINER_ROS_SRC="/tmp/cache/ros/src"

mkdir -p ${IN_CONTAINER_ROS_SRC}
# shadow clone to avoid workspace polution
cp -r $IN_CONTAINER_MOUNT_POINT ${IN_CONTAINER_ROS_SRC}

# setup the paths through envs
export MOVAI_USERSPACE=/tmp
export MOVAI_PACKAGING_DIR=${IN_CONTAINER_ROS_SRC}
export MOVAI_OUTPUT_DIR=${IN_CONTAINER_MOUNT_POINT}/build/

/usr/local/bin/ros1-workspace-build.sh
/usr/local/bin/ros1-workspace-package.sh