#!/bin/bash
# post install script

COMPONENT="@(Package)"

if [ "$1" == "configure" ]; then

    COMPONENT_INSTALL_PATH="/opt/ros/$ROS_DISTRO/share/$COMPONENT"
    MOVAI_BACKUP_TOOL_PATH="/opt/mov.ai/app"
    MOBDATA_PATH="/usr/local/bin/mobdata"

    if [ -x /usr/local/bin/mobdata ]; then
        echo -e "\033[0;33mImporting through mobdata.\033[0m"
        $MOBDATA_PATH import -f -i -c -m "$COMPONENT_INSTALL_PATH/manifest.txt" -r $COMPONENT_INSTALL_PATH -p "$COMPONENT_INSTALL_PATH/metadata" || exit 1
    elif [ -d "$MOVAI_BACKUP_TOOL_PATH/tools" ]
    then
        pushd $MOVAI_BACKUP_TOOL_PATH || exit 1
        echo -e "\033[0;33mWARNING: Going for the deprecated import method. Utils tools.backup.\033[0m"
        sudo -u movai /usr/bin/python3 -m tools.backup -f -i -c -a import -m "$COMPONENT_INSTALL_PATH/manifest.txt" -r $COMPONENT_INSTALL_PATH -p "$COMPONENT_INSTALL_PATH/metadata" || exit 1
        popd || exit 1
    else 
        echo -e "\033[0;33mWARNING: MOVAI tools not found. Skipped installation of movai metadata\033[0m"
    fi


elif [ "$1" == "abort-remove" ]; then
    rm -r $COMPONENT_INSTALL_PATH || true

    #remove from database 
fi
