#!/bin/bash
# post install script

COMPONENT=@(Package)

if [ "$1" == "configure" ]; then

    COMPONENT_INSTALL_PATH="/opt/ros/$ROS_DISTRO/share/$COMPONENT"
    MOVAI_BACKUP_TOOL_PATH="/opt/mov.ai/app"

    if [ -d "$MOVAI_BACKUP_TOOL_PATH/tools" ]
    then
        pushd $MOVAI_BACKUP_TOOL_PATH || exit 1
        sudo -u movai /usr/bin/python3 -m tools.backup -f -i -a import -m "$COMPONENT_INSTALL_PATH/manifest.txt" -r $COMPONENT_INSTALL_PATH -p "$COMPONENT_INSTALL_PATH/metadata" || exit 1
        popd || exit 1
    else 
        echo -e "\033[0;33mWARNING: MOVAI tools not found. Skipped installation of movai metadata\033[0m"
    fi


elif [ "$1" == "abort-remove" ]; then
    rm -r $COMPONENT_INSTALL_PATH || true

    #remove from database 
fi
