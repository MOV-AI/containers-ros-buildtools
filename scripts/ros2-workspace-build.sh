#!/bin/bash
#
# Copyright 2026 MOV.AI
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
# File: ros2-workspace-build.sh

BUILD_MODE="${BUILD_MODE:-RELEASE}"
# Type of dependency packages to install when using rosdep
# Eg: ROSDEP_INSTALL_DEPENDENCY_TYPES="buildtool build_export exec doc test build buildtool_export"
ROSDEP_INSTALL_DEPENDENCY_TYPES="${ROSDEP_INSTALL_DEPENDENCY_TYPES:-all}"
ROSDEP_CHECK_FAIL_MSG_FILTER_KEY="Cannot locate rosdep definition for"

set -e
sudo apt-get update

# We will now build the user ROS2 workspace
printf "Updating ROS2 Workspace:\n"
cd ${ROS2_USER_WS} >/dev/null

if [ "$BUILD_MODE" = "RELEASE" ]
then
    CMAKE_ARGS='--cmake-args -DCMAKE_BUILD_TYPE=Release'
else
    if [ -z "$CMAKE_ARGS" ]; then
        CMAKE_ARGS='--cmake-args -DCMAKE_BUILD_TYPE=Debug'
    fi
fi

BUILD_LIMITS="${BUILD_LIMITS:---cmake-args -j2 -l2 --mem-limit 50%}"
BUILD_ARGS="${BUILD_LIMITS}"

printf "Configuring ROS2 Workspace with args:\n"
printf "\t env: %s\n" "${MOVAI_ENV}"
printf "\t cmake: %s\n" "${CMAKE_ARGS}"

# dependencies using rosdep
rosdep install --from-paths ./ --ignore-src --rosdistro ${ROS_DISTRO} -y --as-root pip:false

# Build User Workspace
printf "Building ROS2 Workspace with args:\n"
printf "\t args: %s\n" "${BUILD_ARGS}"
colcon build ${BUILD_ARGS} ${CMAKE_ARGS} ${@:1}
