#!/bin/bash
# post install script

# this should require movai-backend to be installed

COMPONENT=@(Package)

if [ "$1" == "configure" ]; then

    COMPONENT_INSTALL_PATH="/usr/share/$COMPONENT"

    # upload database
    sudo -u movai /usr/bin/python3 -m tools.backup -f -a import -m "$COMPONENT_INSTALL_PATH/manifest.txt" -r $COMPONENT_INSTALL_PATH -p "$COMPONENT_INSTALL_PATH/movai_metadata" || exit 1


elif [ "$1" == "abort-remove" ]; then
    rm -r $COMPONENT_INSTALL_PATH || true

    #remove from database 
fi
