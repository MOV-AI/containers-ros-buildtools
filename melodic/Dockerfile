FROM registry.cloud.mov.ai/devops/movai-base:melodic

RUN mkdir /movai_projects && \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y \
        cmake \
        python-bloom \
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
        ros-melodic-catkin \
        python3-catkin-tools \
        python3-osrf-pycommon \
    && pip3 install --upgrade pip \
    && pip3 install \
        awscli
RUN apt-get upgrade -y tar
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \ 
    tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt update && \
    apt install gh

# Run everything as mov.ai user
USER movai
