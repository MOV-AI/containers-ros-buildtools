#!/bin/bash
#
# Copyright 2021 Mov AI
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
# File: ros1-workspace-package.sh

MOVAI_PACKAGE_OS="${MOVAI_PACKAGE_OS:-ubuntu}"
MOVAI_PACKAGE_OS_VERSION="$(lsb_release -cs)"
MOVAI_PACKAGE_VERSION="${MOVAI_PACKAGE_VERSION:-0.0.0-dirty}"

# function to generate the deb of a ros component in a given path
function generate_package(){

    SUB_COMPONENT_DIR=$1
    printf "Packaging ros project in $SUB_COMPONENT_DIR.\n"

    cd "${SUB_COMPONENT_DIR}"

    bloom-generate rosdebian --os-name "${MOVAI_PACKAGE_OS}" \
    --os-version "${MOVAI_PACKAGE_OS_VERSION}" --ros-distro "${ROS_DISTRO}" .

    if [ -d "../movai_metadata/" ]
    then
        printf "Component contains movai metadata. Incorporating it in deb.\n"
    else
        printf "No movai metadata detected.\n"
        rm -f ./debian/install
        rm -f ./debian/postinst
    fi

    # update version
    dch -b -v "${MOVAI_PACKAGE_VERSION}" "Auto created package version: ${MOVAI_PACKAGE_VERSION}"

    # create .deb
    dpkg-buildpackage -nc -b -rfakeroot -us -uc -tc | tee "${SUB_COMPONENT_DIR}/dpkg-${MOVAI_PACKAGE_NAME}.log"
    
}


SUB_COMPONENTS="$(dirname $(find -L ${MOVAI_PACKAGING_DIR} -name package.xml))"

for SUB_COMPONENT_PATH in $SUB_COMPONENTS; do # Not recommended, will break on whitespace
    generate_package "$SUB_COMPONENT_PATH"
done

if [ ! -z "${MOVAI_OUTPUT_DIR}" ];
then
    if [ ! -d "${MOVAI_OUTPUT_DIR}" ];
    then
        mkdir -p ${MOVAI_OUTPUT_DIR}
    fi
    echo "Copying debs to ${MOVAI_OUTPUT_DIR}"
    find ${MOVAI_PACKAGING_DIR} -type f -name '*.deb' | 
    while read GEN_DEB; do cp "$GEN_DEB" "${MOVAI_OUTPUT_DIR}"; done

fi

# -a ${props.packageArch}
# export GPG_TTY=$(tty)
# dpkg-buildpackage -nc -b -rfakeroot --sign-key="${DEB_SIGN_KEYID}"
