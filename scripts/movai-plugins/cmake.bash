#!/bin/bash

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || {
    echo "This script ment to be sourced ..."
    return 1
}

function pkg_get_checksum () {

    local BUILD_PATH=${MOVAI_USERSPACE}/cache/src/${PACKAGE_NAME}

    [ -d ${BUILD_PATH} ] || echo ${PACKAGE_CONF_package__version}; return;

    echo "${PACKAGE_VERSION}-$(md5deep -rl ${BUILD_PATH})"
}

function pkg_install () {

    local PACKAGE_NAME="${PACKAGE_CONF_package__name}"
    local PACKAGE_VERSION="${PACKAGE_CONF_package__version}"
    local PACKAGE_TYPE="${PACKAGE_CONF_package__type}"
    local PACKAGE_SOURCE="${PACKAGE_CONF_package__source}"
    local PACKAGE_WORKFOLDER="${PACKAGE_CONF_package__workfolder}"
    local PACKAGE_BUILD_ARGUMENTS="${PACKAGE_CONF_package__build_arguments}"
    local PACKAGE_CMAKE_ARGUMENTS="${PACKAGE_CONF_package__cmake_arguments}"
    local PACKAGE_INSTALL_ARGUMENTS="${PACKAGE_CONF_package__install_arguments}"
    local PACKAGE_PRE_FETCH="${PACKAGE_CONF_package__pre_fetch_command}"
    local PACKAGE_POST_FETCH="${PACKAGE_CONF_package__post_fetch_command}"
    local PACKAGE_PRE_BUILD="${PACKAGE_CONF_package__pre_build_command}"
    local PACKAGE_POST_BUILD="${PACKAGE_CONF_package__post_build_command}"
    local PACKAGE_PRE_INSTALL="${PACKAGE_CONF_package__pre_install_command}"
    local PACKAGE_POST_INSTALL="${PACKAGE_CONF_package__post_install_command}"

    unset INSTALL_ERROR
    trap install_error_trap ERR
    trap install_quit_trap SIGINT SIGTSTP

    local BUILD_PATH=${MOVAI_USERSPACE}/cache/src/${PACKAGE_NAME}
    mkdir -p ${BUILD_PATH}
    cd ${BUILD_PATH} >/dev/null

    eval "${PACKAGE_PRE_FETCH}"
    movai_get_source ${PACKAGE_SOURCE} ${PACKAGE_VERSION} || exit 1

    eval "${PACKAGE_POST_FETCH}"

    eval "${PACKAGE_PRE_BUILD}"
    if [ ! -z ${PACKAGE_WORKFOLDER} ]; then
        pushd ${PACKAGE_WORKFOLDER} > /dev/null
    fi
    mkdir -p build
    pushd build >/dev/null
    cmake .. ${PACKAGE_CMAKE_ARGUMENTS}
    make ${PACKAGE_BUILD_ARGUMENTS}
    popd >/dev/null
    eval "${PACKAGE_POST_BUILD}"
    if [ ! -z ${PACKAGE_WORKFOLDER} ]; then
        popd > /dev/null
    fi
    eval "${PACKAGE_PRE_INSTALL}"
    if [ ! -z ${PACKAGE_WORKFOLDER} ]; then
        pushd ${PACKAGE_WORKFOLDER} > /dev/null
    fi
    pushd build >/dev/null
    sudo make install
    popd >/dev/null
    if [ ! -z ${PACKAGE_WORKFOLDER} ]; then
        popd > /dev/null
    fi
    eval "${PACKAGE_POST_INSTALL}"
}
