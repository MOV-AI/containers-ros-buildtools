FROM registry.cloud.mov.ai/devops/movai-base:noetic

RUN mkdir /movai_projects && \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y \
        cmake \
        python3-bloom \
        git \
        zip \
        unzip \
        software-properties-common \
        nano \
        bash \
        openssh-client \
        debhelper \
        build-essential \
        devscripts \
        ros-noetic-catkin \
        python3-catkin-tools \
        python3-osrf-pycommon \
    && pip3 install --upgrade pip \
    && pip3 install \
        awscli
RUN apt-get upgrade -y tar

### Environment config
ENV MOVAI_ENV="$MOVAI_BRANCH" \
    MOVAI_USERSPACE="${MOVAI_HOME}/user" \
    ROS_VERSION="${ROS_DISTRO}" \
    ROS1_MOVAI_WS="${MOVAI_HOME}/workspaces/MOVAI_ROS1" \
    ROS2_MOVAI_WS="${MOVAI_HOME}/workspaces/MOVAI_ROS2" \
    ROS1_USER_WS="${MOVAI_HOME}/workspaces/USER_ROS1" \
    ROS2_USER_WS="${MOVAI_HOME}/workspaces/USER_ROS2"

# Specific tasks to do to the user homespace
COPY scripts/user.rc /tmp/user.rc
RUN /usr/local/bin/user-provision.sh

# Copy runtime scripts
COPY scripts/movai-packaging.bash /usr/local/lib/movai-packaging.bash
COPY scripts/movai-plugins/ /usr/local/lib/movai-plugins/
COPY scripts/backup.sh /usr/local/bin/backup.sh
COPY scripts/ros1-workspace-build.sh /usr/local/bin/ros1-workspace-build.sh
COPY scripts/ros1-workspace-package.sh /usr/local/bin/ros1-workspace-package.sh
COPY scripts/provision.sh /usr/local/bin/provision.sh


# Run everything as mov.ai user
USER movai