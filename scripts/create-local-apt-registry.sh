#!/bin/bash
REGISTRY_PATH="/usr/local/apt-registry"

RELOAD_REGISTRY_SCRIPT_NAME="reload-local-debs.sh"
RELOAD_REGISTRY_SCRIPT_PATH="/usr/local/bin"

mkdir -p "${REGISTRY_PATH}" "${RELOAD_REGISTRY_SCRIPT_PATH}"

# Create script for local registry debian list reload
printf "\
    #! /bin/bash \n\
    cd ${REGISTRY_PATH} \n \
    dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz " > "${RELOAD_REGISTRY_SCRIPT_PATH}/${RELOAD_REGISTRY_SCRIPT_NAME}"

chmod +x "${RELOAD_REGISTRY_SCRIPT_PATH}/${RELOAD_REGISTRY_SCRIPT_NAME}"
chown 1000 "${REGISTRY_PATH}"

# Run the Reload registry content script and make it avaiable for movai user
bash "${RELOAD_REGISTRY_SCRIPT_PATH}/${RELOAD_REGISTRY_SCRIPT_NAME}"
chown 1000:1000 "${REGISTRY_PATH}/Packages.gz"

# Have apt use our local registry
echo -e "deb [trusted=yes] file:${REGISTRY_PATH} ./ \n$(cat /etc/apt/sources.list)" > /etc/apt/sources.list 

