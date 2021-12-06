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


#INPUTS NEEDED
# - MOVAI_PACKAGING_DIR (ROOT OF YOUR PROJECT)

MOVAI_PACKAGE_OS="${MOVAI_PACKAGE_OS:-ubuntu}"

#constants
STDERR_TMP_FILE="/tmp/build-stderr.log"
FAILURE_ROSDEP_MISSING_DEPENDENCY="Could not resolve rosdep key"
LOCAL_REGISTRY="/usr/local/apt-registry"
MOVAI_PACKAGE_OS_VERSION="$(lsb_release -cs)"

function local_publish(){
    pkg_name=$1

    find -L ../ -name "${pkg_name}*.deb" |
    while read GEN_DEB; do cp "$GEN_DEB" "${LOCAL_REGISTRY}"; done

    
    # have rosdep sources use ros-pkgs.yaml
    bash enable-custom-rosdep.sh "LOCAL"

    #ros package name from deb name
    ros_pkg_name=$(echo "$pkg_name" | sed -e 's/ros-\w*-'//g)
    #replace - with _. ros naming conventions
    ros_pkg_name=$(echo "$ros_pkg_name" | sed 's/-/_/g')

    # yaml format for rosdep dependency translation
    printf "\
        \n$ros_pkg_name:\
        \n ubuntu:\
        \n  $MOVAI_PACKAGE_OS_VERSION:\
        \n   apt:\
        \n    packages: [$pkg_name] \n" >> /usr/local/rosdep/ros-pkgs.yaml

}

function boostrap_debian_metadata_ros_meta_pkg(){
    # possible limitation of doom
            printf '#!/usr/bin/make -f
            \n%%:\n\tdh $@
            \noverride_dh_auto_configure:
            ' > "./debian/rules"
    }

function boostrap_debian_metadata_ros_pkg(){

    if [ -d "../movai_metadata/" ]
    then
        echo -e "\e[31mStill using movai_metadata folder which is no longer acceptable. Please change to metadata.\033[0m"
        set -e 
        exit 2
    fi

    if [ -d "../metadata/" ]
    then
        echo -e "\033[0;33mComponent contains movai metadata. Incorporating it in deb.\033[0m"
    else
        echo -e "\033[0;33mNo movai metadata detected.\033[0m"
        rm -f ./debian/install
        rm -f ./debian/postinst
    fi
}

function overwrite_control_architecture(){
    desired_arch="Architecture: all"

    anchor=$(cat debian/control | grep Architecture)

    if [ -z "$anchor" ]; then
        echo "$desired_arch" >>debian/control
    fi
    
    sed -i "s/$anchor/$desired_arch/g" debian/control

}

function is_ros_metapackage(){
    package_path=$1

    if [ -z "$package_path" ]; then
        package_path="./package.xml"
    fi
       
    result="$(grep "<metapackage" $package_path)"
    IS_ROS_META_PKG=1
    if [ $result ]
    then
        IS_ROS_META_PKG=0
    fi
    
}

# function to generate the deb of a ros component in a given path
function generate_package(){

    SUB_COMPONENT_DIR=$1

    printf "Packaging ros project in $SUB_COMPONENT_DIR.\n"

    cd "${SUB_COMPONENT_DIR}"

    if [ -n "${SRC_REPO}" ];
    then
        boostrap_url_ros_package_xml "${SUB_COMPONENT_DIR}/package.xml" 
    fi
    result=$(echo n | bloom-generate rosdebian --os-name "${MOVAI_PACKAGE_OS}" --os-version "${MOVAI_PACKAGE_OS_VERSION}" --ros-distro "${ROS_DISTRO}" . 2> $STDERR_TMP_FILE)

    # generated the deb metadata sucessfully including passing dependencies validation?
    if [ $? -eq 0 ]
    then
        is_ros_metapackage 
        if [ $IS_ROS_META_PKG -eq 0 ]
        then
            boostrap_debian_metadata_ros_meta_pkg
        fi

        boostrap_debian_metadata_ros_pkg
        # update version
        dch -b -v "${MOVAI_PACKAGE_VERSION}" "Auto created package version: ${MOVAI_PACKAGE_VERSION}"

        pkg_name="$(dpkg-parsechangelog -S Source)"
        pkg_log_TMP_FILE="/tmp/$pkg_name-build.log"

        # overwrite control auto discovery of architecture to "all".
        overwrite_control_architecture

        dpkg-buildpackage -nc -b -rfakeroot -us -uc -tc 2> $pkg_log_TMP_FILE

        deb_found=$(find -L ../ -name "${pkg_name}*.deb") 
        if [ ! "$deb_found" ]
        then
            # print failure
            echo -e "\e[31mFailed during packaging :\033[0m"
            cat $pkg_log_TMP_FILE
            set -e 
            exit 1
        fi
            
        local_publish $pkg_name
        rosdep update

    else
        reason_identified=$(cat $STDERR_TMP_FILE | grep "$FAILURE_ROSDEP_MISSING_DEPENDENCY")

        if [ -n "$reason_identified" ]
        then
            printf "Failure: $reason_identified. \n Postponing packaging for possible dependencies to be generated.\n"
            FAILED_DEB_BUILDS+=("$SUB_COMPONENT_DIR")
        else
            echo -e "\e[31mFailed during instantiation of meta data before packaging :"          
            reason_identified=$(cat $STDERR_TMP_FILE)

            echo -e "\e[31m$reason_identified.\033[0m"
            set -e
            exit 2
        fi
    fi

}

function boostrap_url_ros_package_xml(){
    package_xml=$1

    url_section=$(cat $package_xml | grep url)
    new_url_section="  <url>$SRC_REPO<\/url>"

    if [ ! "$url_section" ]
    then
        anchor="<\/version>"
        sed -i "s,$anchor,$anchor\n$new_url_section,g" $package_xml
    else
        sed -i "s,$url_section,$new_url_section,g" $package_xml
    fi
}

function find_main_package_version(){
    main_package=$(cat /tmp/main-package.mobrosinfo)
    build_version_section=$(cat $main_package | grep build_version)
    version_section=$(cat $main_package | grep "<version")
    main_version=$(echo $version_section | sed 's/ //g' | sed -e 's/<\w*>'//g | sed -e 's/<\/\w*>'//g)
    buildid=$(echo $build_version_section | sed 's/ //g' | sed -e 's/<\w*>'//g | sed -e 's/<\/\w*>'//g)
    MOVAI_PACKAGE_VERSION="$main_version-$buildid"
}


find_main_package_version

SUB_COMPONENTS="$(dirname $(find -L ${MOVAI_PACKAGING_DIR} -name package.xml) | awk '{ print length, $0 }' | sort -rn | cut -d" " -f2-)"
for SUB_COMPONENT_PATH in $SUB_COMPONENTS; do
    generate_package "$SUB_COMPONENT_PATH"
done

max_attempts=5
for (( i=1; i<=$max_attempts; i++ ))
do  
    echo "Attempt number $i on resolving dependencies. Re-iterating the projects that have been postponed."
    
    if [ ${#FAILED_DEB_BUILDS[@]} -ne 0 ]; then

        iterator=("${FAILED_DEB_BUILDS[@]}")   
        FAILED_DEB_BUILDS=()
        for SUB_COMPONENT_PATH in "${iterator[@]}"; do
            generate_package "$SUB_COMPONENT_PATH"
        done
    
    fi

done


# report results

expected_pkgs=$(find -L ${MOVAI_PACKAGING_DIR} -name package.xml | wc -l)
obtained_pkgs=$(find -L ${MOVAI_PACKAGING_DIR} -name "*.deb" | wc -l)

echo -e "\033[1;35m============================================\033[0m"
echo -e "\033[0;36mROS-WORKSPACE-PACKAGE SCRIPT SUMMARY:"
echo -e "\033[0;36mGenerated packages: \033[1;33m$obtained_pkgs \033[0;36mof \033[1;32m$expected_pkgs"
echo -e "\033[1;35m============================================\033[0m"

#copy to output dir if needed
if [ -n "${MOVAI_OUTPUT_DIR}" ];
then
    if [ ! -d "${MOVAI_OUTPUT_DIR}" ];
    then
        mkdir -p "${MOVAI_OUTPUT_DIR}"
    fi
    echo "Copying debs to ${MOVAI_OUTPUT_DIR}"

    find -L "${MOVAI_PACKAGING_DIR}" -type f -name '*.deb' -exec cp {} "${MOVAI_OUTPUT_DIR}" \;

fi

