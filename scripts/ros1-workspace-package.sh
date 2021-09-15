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

MOVAI_PACKAGING_DIR="$(find ${MOVAI_PACKAGING_DIR} -name debian)/.."
print "I AM GONNA CD TO $MOVAI_PACKAGING_DIR"
cd "${MOVAI_PACKAGING_DIR}"

bloom-generate rosdebian --os-name "${MOVAI_PACKAGE_OS}" \
--os-version "${MOVAI_PACKAGE_OS_VERSION}" --ros-distro "${ROS_DISTRO}" .

# update version
dch -b -v "${MOVAI_PACKAGE_VERSION}" "Auto created package version: ${MOVAI_PACKAGE_VERSION}"

# create .deb
dpkg-buildpackage -nc -b -rfakeroot -us -uc -tc | tee "${MOVAI_PACKAGING_DIR}/dpkg-${MOVAI_PACKAGE_NAME}.log"
cp ./../*.deb ./../build


# -a ${props.packageArch}
# export GPG_TTY=$(tty)
# dpkg-buildpackage -nc -b -rfakeroot --sign-key="${DEB_SIGN_KEYID}"
