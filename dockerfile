FROM ubuntu:20.04

RUN useradd -ms /bin/bash movai
RUN mkdir /movai_projects && \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y \
        python3 \
        cmake \
        python3-pip \
        git \
        zip \
        unzip \
        software-properties-common \
        wget \
        sudo \
        nano \
        npm \
        bash \
        curl \
        openssh-client \
        debhelper \
        build-essential \
        devscripts \
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


RUN adduser movai sudo &&\
    echo "%sudo ALL=(ALL) NOPASSWD:SETENV: /usr/bin/apt-get" >> /etc/sudoers.d/movai &&\
    echo "%sudo ALL=(ALL) NOPASSWD:SETENV: /usr/bin/apt" >> /etc/sudoers.d/movai && \
    echo "%sudo ALL=(ALL) NOPASSWD:SETENV: /usr/bin/apt-key" >> /etc/sudoers.d/movai  &&\
    echo "%sudo ALL=(ALL) NOPASSWD:SETENV: /usr/bin/apt-cache" >> /etc/sudoers.d/movai &&\
    echo "%sudo ALL=(ALL) NOPASSWD:SETENV: /usr/bin/apt-mark" >> /etc/sudoers.d/movai &&\
    echo "%sudo ALL=(ALL) NOPASSWD:SETENV: /usr/bin/add-apt-repository" >> /etc/sudoers.d/movai 
RUN cat /etc/sudoers.d/movai

# Run everything as mov.ai user
USER movai
WORKDIR /home/movai