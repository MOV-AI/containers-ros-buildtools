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
# File: movai.bash

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || {
    echo "This script ment to be sourced ..."
    return 1
}

shopt -s expand_aliases

#alias run="[ ! -z ${INSTALL_ERROR} ] && { [ ${INSTALL_ERROR} -eq 2 ] && { echo \"Quiting....\"; exit; } || { echo \"Skipping...\"; return; } };"

# Set and create package history folder if it not exists
PKG_CHECKSUM_DIR=/opt/mov.ai/etc/packages
mkdir -p ${PKG_CHECKSUM_DIR}

function parse_yaml() {
    local prefix=$2
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @ | tr @ '\034')
    sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" $1 |
        awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

function check_ssh_keys() {
    if [ -f $HOME/.ssh/id_rsa.pub ]
    then
        printf "\n${yellow}You're keys are already set up:- You must ensure this public key is added to your bitbucket account${reset}\n"
        printf "\n${yellow}$( cat ~/.ssh/id_rsa.pub)${reset}\n"
     else
	    cat /dev/zero | ssh-keygen -q -N "" -f "/home/$USER/.ssh/id_rsa"&&printf "\n${yellow}You're keys are now set up:- You must ensure this public key is added to your bitbucket account or the source clone will fail.\nid_rsa.pub:\n${reset}\n"
        printf "\n${yellow}$id_rsa_pub\n\n${reset}\n"
     fi
 }

function check_for_ssh() {
	printf "\n${green}generate ssh keys if not set up already..${reset}\n"
	check_ssh_keys
    ssh-keyscan bitbucket.org > BitbucketKey
    ssh-keygen -lf BitbucketKey
    cat BitbucketKey >> ~/.ssh/known_hosts
    rm BitbucketKey
}

function movai_validate_url() {

    local EXIT_CODE=$(wget -S --spider ${1} 2>&1)

    if echo ${EXIT_CODE} | grep -q 'HTTP/1.1 200 OK'; then
        return 0
    elif echo ${EXIT_CODE} | grep '220'; then
        return 0
    fi

    return 1
}

function movai_get_source() {

    local PACKAGE_SOURCE=${1}
    local PACKAGE_VERSION=${2}

    if git ls-remote ${PACKAGE_SOURCE} -q; then
        if [ ! -d .git ]; then
            git clone --recurse-submodules ${PACKAGE_SOURCE} .
        fi
        git fetch && \
        git checkout ${PACKAGE_VERSION}
        local git_result=$?

        # ignore the git pull exit code. Currently is failing with detached state.
        git pull || return ${git_result}
        return ${git_result}
    else
        if movai_validate_url ${PACKAGE_SOURCE}; then
            local ARTIFACT="$(basename ${PACKAGE_SOURCE})"
            wget ${PACKAGE_SOURCE} -O /tmp/${ARTIFACT}

            local FILE_EXTENSION="${basename##*.}"

            case "${FILE_EXTENSION}" in
            tar.*)
                tar -xvf ${ARTIFACT} || exit 1
                ;;
            zip*)
                unzip ${ARTIFACT} || exit 1
                ;;
            *)
                echo "Unknown filetype!"
                exit 1
                ;;
            esac
            rm --preserve-root /tmp/${ARTIFACT}
            return 0
        fi
    fi
    exit 1
}

function install_error_trap() {
    printf "Error during package installation!\n"
    INSTALL_ERROR=1
    exit 1
}

function install_quit_trap() {
    printf "Operation cancelled by the user!\n"
    INSTALL_ERROR=2
    exit 2
}

function movai_install_apt() {

    local PACKAGES_LOCATION=${1}

    if [ -f ${PACKAGES_LOCATION}/packages.apt ]; then
        printf "[Installing apt] Start\n"
        local CURR_CHECKSUM=$(md5sum ${PACKAGES_LOCATION}/packages.apt | awk '{ print $1 }')

        if [ -f ${PKG_CHECKSUM_DIR}/packages.apt ]; then
            local PACKAGE_CHECKSUM=$(cat ${PKG_CHECKSUM_DIR}/packages.apt)
        fi

        if [ "${PACKAGE_CHECKSUM}" != "${CURR_CHECKSUM}" ]; then
            sudo apt-get update >/dev/null

            echo "[Installing apt] Installing apt-packages from ${PACKAGES_LOCATION}/packages.apt"
            packages_list=$(cat "${PACKAGES_LOCATION}/packages.apt" | sed -e 's/#.*$//' -e '/^$/d' | sed ':a;N;$!ba;s/\n/ /g')

            echo "[Installing apt] Installing $packages_list"
            export DEBIAN_FRONTEND=noninteractive
            sudo apt-get -yq --no-install-recommends install $packages_list

            sudo apt-get clean -y

            echo ${CURR_CHECKSUM} >${PKG_CHECKSUM_DIR}/packages.apt
        fi
        printf "[Installing apt] End\n"
        printf "%s\n" "-----------------------"

    fi
}

function movai_install_pip() {

    local PACKAGES_LOCATION=${1}

    if [ -f ${PACKAGES_LOCATION}/requirements.txt ]; then
        printf "[Installing pip] Start\n"
        local CURR_CHECKSUM=$(md5sum ${PACKAGES_LOCATION}/requirements.txt | awk '{ print $1 }')

        if [ -f ${PKG_CHECKSUM_DIR}/requirements.txt ]; then
            local PACKAGE_CHECKSUM=$(cat ${PKG_CHECKSUM_DIR}/requirements.txt)
        fi

        if [ "${PACKAGE_CHECKSUM}" != "${CURR_CHECKSUM}" ]; then
            printf "[Installing pip] Installing PIP packages from ${PACKAGES_LOCATION}/requirements.txt\n"
            python3 -m pip install -r ${PACKAGES_LOCATION}/requirements.txt
        fi
        printf "[Installing pip] End\n"
        printf "%s\n" "-----------------------"
    fi
}

function movai_install_bash_scripts() {

    local PACKAGES_LOCATION=${1}
    printf "[Installing bash] Start\n"
    for PACKAGE in ${PACKAGES_LOCATION}/*.bash; do

        local PACKAGE_NAME="$(basename ${PACKAGE})"

        source ${PACKAGES_LOCATION}/${PACKAGE_NAME%%.*}.bash

        unset CURR_CHECKSUM

        if type -t pkg_get_checksum | grep -q "^function$"; then
            local CURR_CHECKSUM=$(pkg_get_checksum)
            unset -f pkg_get_checksum
        else
            printf "This package (%s) does not support checksum, it will not be able to track changes!\n" "${PACKAGE_NAME%%.*}"
        fi

        if [ -f ${PKG_CHECKSUM_DIR}/$(basename ${PACKAGE}) ]; then

            local PACKAGE_CHECKSUM=$(cat ${PKG_CHECKSUM_DIR}/$(basename ${PACKAGE}))

            if [ "${PACKAGE_CHECKSUM}" = "${CURR_CHECKSUM}" ]; then
                continue
            fi
        fi

        if type -t pkg_install | grep -q "^function$"; then
            pkg_install
            unset -f pkg_install
        else
            printf "Something is wrong when installing package %s!\n" "${PACKAGE_NAME%%.*}"
            exit 1
        fi

        [ ! -z ${CURR_CHECKSUM} ] && echo ${CURR_CHECKSUM} >${PKG_CHECKSUM_DIR}/$(basename ${PACKAGE})
    done
    printf "[Installing bash] End\n"
    printf "%s\n" "-----------------------"

}

function movai_install_yaml_scripts() {

    local PACKAGES_LOCATION=${1}
    printf "[Installing yaml] Start\n"
    for PACKAGE in "${PACKAGES_LOCATION}"/*.yml; do

        local PACKAGE_NAME="$(basename ${PACKAGE})"
        eval $(parse_yaml ${PACKAGES_LOCATION}/${PACKAGE_NAME%%.*}.yml "PACKAGE_CONF_")

        PACKAGE_NAME="${PACKAGE_CONF_package__name}"
        PACKAGE_VERSION="${PACKAGE_CONF_package__version}"
        PACKAGE_TYPE="${PACKAGE_CONF_package__type}"

        printf "[Installing yaml] Processing package: ${PACKAGE_NAME}, revision: ${PACKAGE_VERSION}\n"

        if [ ! -e /usr/local/lib/movai-plugins/${PACKAGE_TYPE%%.*}.bash ]; then
            printf "Package type not known - %s! \n" "${PACKAGE_NAME}"
            exit 1
        fi

        source /usr/local/lib/movai-plugins/${PACKAGE_TYPE%%.*}.bash

        unset CURR_CHECKSUM

        if type -t pkg_get_checksum | grep -q "^function$"; then
            local CURR_CHECKSUM=$(pkg_get_checksum)
            unset -f pkg_get_checksum
        else
            printf "This package (%s) does not support checksum, it will not be able to track changes!\n" "${PACKAGE_NAME%%.*}"
            continue
        fi

        if [ -f ${PKG_CHECKSUM_DIR}/$(basename ${PACKAGE}) ]; then

            local PACKAGE_CHECKSUM=$(cat ${PKG_CHECKSUM_DIR}/$(basename ${PACKAGE}))

            if [ "${PACKAGE_CHECKSUM}" = "${CURR_CHECKSUM}" ]; then
                continue
            fi
        fi

        if type -t pkg_install | grep -q "^function$"; then
            pkg_install
            unset -f pkg_install
        else
            printf "Something is wrong when installing package %s!\n" "${PACKAGE_NAME%%.*}"
            exit 1
        fi

        if [ -z ${INSTALL_ERROR} ]; then
            echo ${CURR_CHECKSUM} >${PKG_CHECKSUM_DIR}/$(basename ${PACKAGE})
        else
            printf "Installation error detected! exiting."
            exit 1
        fi

        unset "${!PACKAGE_CONF@}"
    done
    printf "[Installing yaml] End\n"
    printf "%s\n" "-----------------------"
}

function movai_install_rosinstall() {

    local PACKAGES_LOCATION=${1}
    printf "[Installing rosinstal] Start\n"
    check_for_ssh
    printf "Initialiazing ROS1 Workspace ...\n"
    local ROS_WS_INIT_RESULT=0
    local ERR_LOG_FILE="/tmp/provision.init.ros.err"
    rm -f "$ERR_LOG_FILE"

    wstool init ${MOVAI_USERSPACE}/cache/ros/src &> >(tee -a "$ERR_LOG_FILE")  || ROS_WS_INIT_RESULT=1
    if [[ $ROS_WS_INIT_RESULT -eq 0 ]]
    then
        echo  "Created Sucessfully!"
    else
        if grep -Fq "There already is a workspace config file .rosinstall at" "$ERR_LOG_FILE"
        then
            echo  "Workspace already initialized. Continuing."
        else
            echo "Error executing wstool init."
            exit 1
        fi
    fi

    for PACKAGE in ${PACKAGES_LOCATION}/*.rosinstall; do

        local CURR_CHECKSUM=$(md5sum ${PACKAGE} | awk '{ print $1 }')

        if [ -f ${PKG_CHECKSUM_DIR}/$(basename ${PACKAGE}) ]; then

            local PACKAGE_CHECKSUM=$(cat ${PKG_CHECKSUM_DIR}/$(basename ${PACKAGE}))

            if [ "${PACKAGE_CHECKSUM}" = "${CURR_CHECKSUM}" ]; then
                continue
            fi
        fi

        printf "Preparing ROS1 packages from file: %s\n" "$(basename ${PACKAGE})"
        wstool merge -t ${MOVAI_USERSPACE}/cache/ros/src ${PACKAGE}
        wstool update -t ${MOVAI_USERSPACE}/cache/ros/src
        rosdep install -y --from-paths ${MOVAI_USERSPACE}/cache/ros/src --ignore-src --rosdistro ${ROS_DISTRO}

        echo ${CURR_CHECKSUM} >${PKG_CHECKSUM_DIR}/$(basename ${PACKAGE})
    done
    printf "[Installing rosinstal] End\n"
    printf "%s\n" "-----------------------"
}

function movai_install_packages() {

    if [ $# -eq 0 ]; then
        printf "Please specify packages location!"
        return
    fi

    local PACKAGES_LOCATION=${1}

    if [ -d ${PACKAGES_LOCATION} ]; then

        movai_install_apt ${PACKAGES_LOCATION}
        movai_install_pip ${PACKAGES_LOCATION}
        movai_install_bash_scripts ${PACKAGES_LOCATION}
        movai_install_yaml_scripts ${PACKAGES_LOCATION}
        movai_install_rosinstall ${PACKAGES_LOCATION}

    else
        printf "Packages not available at - %s! \n" "${PACKAGES_LOCATION}"
        exit 1
    fi
}

function install_ssh_key() {

    mkdir -p ${HOME}/.ssh
    [ -f ${MOVAI_USERSPACE}/ssh-keys/id_rsa ] && cp ${MOVAI_USERSPACE}/ssh-keys/id_rsa ${HOME}/.ssh
    [ -f ${MOVAI_USERSPACE}/ssh-keys/id_rsa.pub ] && cp ${MOVAI_USERSPACE}/ssh-keys/id_rsa.pub ${HOME}/.ssh
    chown movai:movai -R ${HOME}/.ssh
    chmod 600 ${HOME}/.ssh/id_rsa*
}
