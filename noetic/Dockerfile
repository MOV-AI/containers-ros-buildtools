ARG DOCKER_REGISTRY="registry.cloud.mov.ai"
ARG DOCKER_TAG=""
FROM ${DOCKER_REGISTRY}/devops/movai-base:noetic

# Arguments
ARG MOVAI_ENV="develop"
ARG MOVAI_BRANCH="develop"
ARG MOVAI_PPA="testing"

# Labels
LABEL description="MOV.AI Buildtools Image"
LABEL maintainer="devops@mov.ai"
LABEL movai="buildtools"
LABEL environment="$MOVAI_ENV"

### Environment config
ENV MOVAI_ENV="$MOVAI_BRANCH" \
    MOVAI_USERSPACE="${MOVAI_HOME}/user" \
    ROS_VERSION="${ROS_DISTRO}" \
    PYTHON_VERSION=3.8 \
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
COPY scripts/ros1-workspace-build-and-package.sh /usr/local/bin/ros1-workspace-build-and-package.sh
COPY scripts/packages.bash /usr/local/bin/packages.bash
COPY scripts/provision.sh /usr/local/bin/provision.sh
COPY scripts/create-local-apt-registry.sh /usr/local/bin/create-local-apt-registry.sh
COPY scripts/rosdep-translation-setup.sh /usr/local/bin/rosdep-translation-setup.sh
COPY scripts/enable-custom-rosdep.sh /usr/local/bin/enable-custom-rosdep.sh
COPY $ROS_VERSION/packages/packages.apt /tmp/packages.apt
COPY $ROS_VERSION/packages/requirements.txt /tmp/requirements.txt
COPY scripts/setup-pypi-env.bash /usr/local/bin/setup-pypi-env.bash
COPY resources/ /usr/local/share/pypi-confs/resources

RUN setup-pypi-env.bash DEV 
RUN /usr/local/bin/enable-custom-rosdep.sh DEV 


USER root

RUN /usr/local/bin/packages.bash && \
    /usr/local/bin/create-local-apt-registry.sh && \
    /usr/local/bin/rosdep-translation-setup.sh

# Install required packages
RUN /usr/local/bin/install-packages.sh

# Configure installations
# config bloom templates
COPY scripts/bloom-plugins/ /usr/lib/python3/dist-packages/bloom/generators/debian/templates/catkin/


# Run everything as mov.ai user
USER movai

RUN mkdir -p /opt/mov.ai/user/cache/ros/build /opt/mov.ai/user/cache/ros/devel /opt/mov.ai/user/cache/ros/logs 
