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
# File: ros1-workspace-build.sh

BUILD_MODE="${BUILD_MODE:-RELEASE}"
# Type of dependency packages to install when using rosdep
# Eg: ROSDEP_INSTALL_DEPENDENCY_TYPES="buildtool build_export exec doc test build buildtool_export"
ROSDEP_INSTALL_DEPENDENCY_TYPES="${ROSDEP_INSTALL_DEPENDENCY_TYPES:"All"}"

set -e
sudo apt-get update

if type -t movai_install_rosinstall | grep -q "^function$"; then
    # If this function is not available means we are calling from shell and not from
    # provision
    source "/usr/local/lib/movai-packaging.bash"
    movai_install_rosinstall ${MOVAI_USERSPACE}/packages
fi

printf "Initialiazing Mov.ai ROS1 Workspace ...\n"
wstool init ${MOVAI_USERSPACE}/cache/ros/src || true

# We will now build the user ROS1 workspace
printf "Updating ROS1 Workspace:\n"
cd ${ROS1_USER_WS} >/dev/null
wstool update -t ${MOVAI_USERSPACE}/cache/ros/src
rosdep update
# Choose what type of dependencies to install using rosdep
# If ROSDEP_INSTALL_DEPENDENCY_TYPES is not defined externally, install all types, else install each given type.
if [ "$ROSDEP_INSTALL_DEPENDENCY_TYPES" = "All" ]; then
  printf "ROSDEP: Installing all dependency types.\n"
  rosdep install --from-paths ${MOVAI_USERSPACE}/cache/ros/src --ignore-src --rosdistro ${ROS_DISTRO} -y
else
  for DEPENDENCY_TYPE in $ROSDEP_INSTALL_DEPENDENCY_TYPES
  do
    printf "ROSDEP: Installing ${DEPENDENCY_TYPE} dependency types.\n"
    rosdep install --from-paths ${MOVAI_USERSPACE}/cache/ros/src --ignore-src --rosdistro ${ROS_DISTRO} --dependency-types=${DEPENDENCY_TYPE} -y
  done
fi

if [ "$BUILD_MODE" = "RELEASE" ]
then
    CMAKE_ARGS='--cmake-args -DCMAKE_BUILD_TYPE=Release'
else
    if [ -z "$CMAKE_ARGS" ]; then
        CMAKE_ARGS='--cmake-args -DCMAKE_BUILD_TYPE=Debug'
    fi
fi


BUILD_LIMITS="${BUILD_LIMITS:--j2 -l2 --mem-limit 50%}"
BUILD_ARGS="${BUILD_LIMITS} -DPYTHON_VERSION=${PYTHON_VERSION:-3.6}"

printf "Configuring ROS1 Workspace with args:\n"
printf "\t env: %s\n" "${MOVAI_ENV}"
printf "\t cmake: %s\n" "${CMAKE_ARGS}"

catkin config\
    --extend /opt/ros/${ROS_DISTRO} --install --merge-install \
    --source-space ${MOVAI_USERSPACE}/cache/ros/src \
    --devel-space ${MOVAI_USERSPACE}/cache/ros/devel \
    --log-space ${MOVAI_USERSPACE}/cache/ros/logs \
    --build-space ${MOVAI_USERSPACE}/cache/ros/build \
    --install-space ${ROS1_USER_WS} \
    ${CMAKE_ARGS}

# Build User Workspace
printf "Building ROS1 Workspace with args:\n"
printf "\t args: %s\n" "${BUILD_ARGS}"
catkin build ${BUILD_ARGS} ${@:1}
