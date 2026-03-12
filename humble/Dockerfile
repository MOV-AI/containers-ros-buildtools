ARG DOCKER_REGISTRY="pubregistry.aws.cloud.mov.ai"
ARG DOCKER_TAG=""
FROM ${DOCKER_REGISTRY}/ce/spawner-base-humble:3.2.2

# Arguments
ARG MOVAI_ENV="develop"
ARG MOVAI_BRANCH="develop"
ARG MOVAI_PPA="ros2-testing"

# Labels
LABEL description="MOV.AI Buildtools Image"
LABEL maintainer="devops@mov.ai"
LABEL movai="buildtools"
LABEL environment="$MOVAI_ENV"

### Environment config
ENV MOVAI_ENV="$MOVAI_BRANCH" \
    MOVAI_USERSPACE="${MOVAI_HOME}/user" \
    ROS_VERSION="${ROS_DISTRO}" \
    PYTHON_VERSION=3.10 \
    ROS2_MOVAI_WS="${MOVAI_HOME}/workspaces/MOVAI_ROS2" \
    ROS2_USER_WS="${MOVAI_HOME}/workspaces/USER_ROS2"

USER root    
# Specific tasks to do to the user homespace
COPY scripts/user.rc /tmp/user.rc
RUN /usr/local/bin/user-provision.sh

# Copy runtime scripts
# [] NEED EQUIVALENT SCRIPTS FOR HUMBLE TO BE CREATED
# COPY scripts/ros1-workspace-build.sh /usr/local/bin/ros1-workspace-build.sh
# COPY scripts/ros1-workspace-package.sh /usr/local/bin/ros1-workspace-package.sh
# COPY scripts/ros1-workspace-raise.sh /usr/local/bin/ros1-workspace-raise.sh
# COPY scripts/ros1-workspace-build-and-package.sh /usr/local/bin/ros1-workspace-build-and-package.sh

COPY scripts/create-local-apt-registry.sh /usr/local/bin/create-local-apt-registry.sh
COPY scripts/rosdep-translation-setup.sh /usr/local/bin/rosdep-translation-setup.sh
COPY scripts/enable-custom-rosdep.sh /usr/local/bin/enable-custom-rosdep.sh
COPY scripts/setup-pypi-env.bash /usr/local/bin/setup-pypi-env.bash
COPY resources/ /usr/local/share/pypi-confs/resources

RUN setup-pypi-env.bash DEV
RUN /usr/local/bin/enable-custom-rosdep.sh PROD


ENV MOVAI_PPA="ros2-testing"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# hadolint ignore=DL3008
# [] NEED EQUIVALENT FOR HUMBLE
# [] NEED DEDICATED BACKUP - line 68
RUN apt-get update && apt-get install -y curl &&\
    curl -fsSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    add-apt-repository ppa:git-core/ppa -y && \
    # gh cli registry
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    # movai registry
    curl -fsSL https://artifacts.cloud.mov.ai/repository/movai-applications/gpg | apt-key add - && \
    add-apt-repository "deb [arch=all] https://artifacts.cloud.mov.ai/repository/ppa-$MOVAI_PPA testing main" && \
    # add-apt-repository "deb [arch=all,amd64] https://artifacts.aws.cloud.mov.ai/repository/ppa-proxy-ros-backup ros-backup main" && \
    apt-get update > /dev/null && \
    apt-get clean -y > /dev/null && \
    rm -rf /var/cache/apt/* && \
    rm -rf /var/lib/apt/lists/* && \
    /usr/local/bin/create-local-apt-registry.sh && \
    /usr/local/bin/rosdep-translation-setup.sh && \
    install -d -m 0777 -o movai -g movai /__w/workspace

# Install required packages    
COPY $ROS_VERSION/packages/packages.apt /tmp/packages.apt
COPY $ROS_VERSION/packages/requirements.txt /tmp/requirements.txt

RUN  echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
    /usr/local/bin/install-packages.sh && \
    chown movai:movai -R /usr/local/

# Configure installations
# config bloom templates
COPY scripts/bloom-plugins/ /usr/local/lib/python3.10/dist-packages/bloom/generators/debian/templates/catkin/

# Run everything as mov.ai user
USER movai

RUN mkdir -p /opt/mov.ai/user/cache/ros/build /opt/mov.ai/user/cache/ros/devel /opt/mov.ai/user/cache/ros/logs && \
    mkdir -p /opt/mov.ai/user/cache/ros2/build /opt/mov.ai/user/cache/ros2/install /opt/mov.ai/user/cache/ros2/logs 

# Set entrypoint for ROS2 build
ENTRYPOINT ["/bin/bash"]