#!/bin/bash

ROSDEP_YAML_PATH="/usr/local/rosdep"
ROSDEP_YAML_FILE="$ROSDEP_YAML_PATH/ros-pkgs.yaml"
GLOBAL_ROSDEP_SOURCELIST_FILE="/etc/ros/rosdep/sources.list.d/20-default.list"

mkdir -p "$ROSDEP_YAML_PATH"
touch $ROSDEP_YAML_FILE

chmod a+rw $ROSDEP_YAML_FILE
chmod a+rw $GLOBAL_ROSDEP_SOURCELIST_FILE
