#!/bin/bash
#
# Copyright 2019 Alexandre Pires (alexandre.pires@mov.ai)
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#  
# File: provision.sh 
set -e

# trap ctrl-c and call ctrl_c()
trap on_control_c INT

function on_control_c() {
    echo "User interrupt"
    exit 1
}

source "/usr/local/lib/movai-packaging.bash"

USER_FOLDERS=(
    ${ROS1_USER_WS}
    ${ROS2_USER_WS}
    ${MOVAI_USERSPACE}
    ${MOVAI_USERSPACE}/cache
    ${MOVAI_USERSPACE}/cache/ros
    ${MOVAI_USERSPACE}/cache/src
    ${MOVAI_USERSPACE}/bags
)

for USER_FOLDER in "${USER_FOLDERS[@]}"; do
    echo "Creating ${USER_FOLDER}"
    mkdir -p ${USER_FOLDER}
done

# Initialize ROS1
source "/opt/ros/${ROS_DISTRO}/setup.bash"
rosdep update

# Install SSH_KEYS if needed
install_ssh_key

if [ -f ${MOVAI_USERSPACE}/hooks/pre-actions.bash ]; then
    # if pre-actions exists we run them
    printf "Running user pre-installation script ...\n"
    /bin/bash ${MOVAI_USERSPACE}/hooks/pre-actions.bash
fi

if [ -d ${MOVAI_USERSPACE}/packages ]; then
    # if packages folder exists we must install provided packages
    printf "Preparing User custom packages\n"
    movai_install_packages ${MOVAI_USERSPACE}/packages
fi

# We will now build the user ROS1 workspace
/usr/local/bin/ros1-workspace-build.sh

# TODO: Install ROS2 workspace

# If the user provides a startup script we copy it to the install location
if [ -f ${MOVAI_USERSPACE}/startup.bash ]; then
    mkdir -p ${ROS1_USER_WS}/bin
    cp ${MOVAI_USERSPACE}/startup.bash ${ROS1_USER_WS}/bin/startup.bash
    chown movai:movai ${ROS1_USER_WS}/bin/startup.bash
    chmod 755 ${ROS1_USER_WS}/bin/startup.bash
fi

if [ -f ${MOVAI_USERSPACE}/hooks/post-actions.bash ]; then
    # if post-actions exists we run them
    printf "Running user post-installation script ...\n"
    /bin/bash ${MOVAI_USERSPACE}/hooks/post-actions.bash
fi
