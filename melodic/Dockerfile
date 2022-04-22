ARG DOCKER_REGISTRY="registry.aws.cloud.mov.ai"
ARG DOCKER_TAG=""
FROM ${DOCKER_REGISTRY}/devops/movai-base-melodic:v1.4.9
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
    PYTHON_VERSION=3.6 \
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
COPY scripts/ros1-workspace-raise.sh /usr/local/bin/ros1-workspace-raise.sh
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
RUN /usr/local/bin/enable-custom-rosdep.sh PROD


USER root

ENV MOVAI_PPA="testing"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# hadolint ignore=DL3008

RUN apt-get update > /dev/null && apt-get upgrade -y &&\
    apt-get clean &&\
    add-apt-repository ppa:git-core/ppa -y && \
    # gh cli registry
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    # movai registry
    curl -fsSL https://artifacts.cloud.mov.ai/repository/movai-applications/gpg | apt-key add - && \
    add-apt-repository "deb [arch=all] https://artifacts.cloud.mov.ai/repository/ppa-$MOVAI_PPA $MOVAI_PPA main" && \
    apt-get update > /dev/null && \
    apt-get install git gh -y --no-install-recommends && \
    apt-get clean -y > /dev/null && \
    rm -rf /var/cache/apt/* && \
    rm -rf /var/lib/apt/lists/* && \
    /usr/local/bin/packages.bash && \
    /usr/local/bin/create-local-apt-registry.sh && \
    /usr/local/bin/rosdep-translation-setup.sh && \
    mkdir /__w  && \
    chmod 777 /__w

# Install required packages
RUN /usr/local/bin/install-packages.sh

# Configure installations
# config bloom templates
COPY scripts/bloom-plugins/ /usr/lib/python2.7/dist-packages/bloom/generators/debian/templates/catkin/

# Run everything as mov.ai user
USER movai

RUN mkdir -p /opt/mov.ai/user/cache/ros/build /opt/mov.ai/user/cache/ros/devel /opt/mov.ai/user/cache/ros/logs
