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
BUILD_MODE="${BUILD_MODE:-RELEASE}"
STRIP_REPLACES="${STRIP_REPLACES:-false}"

#constants
STDERR_TMP_FILE="/tmp/build-stderr.log"
FAILURE_ROSDEP_MISSING_DEPENDENCY="Could not resolve rosdep key"
FAILURE_DEBPACK_MISSING_DEPENDENCY="Could not find a package"
LOCAL_REGISTRY="/usr/local/apt-registry"
MOVAI_PACKAGE_OS_VERSION="$(lsb_release -cs)"

function local_publish(){
    pkg_name=$1
    file_path=$2

    cp "$file_path" "${LOCAL_REGISTRY}"

    
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

    bash reload-local-debs.sh

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
        pkg_name="$(dpkg-parsechangelog -S Source)"

        ROS_DISTRO_ANCHOR='$ROS_DISTRO'
        name_section=$(cat ./package.xml | grep "<name>.*<\/name>")
        package_name=$(echo $name_section | sed 's/ //g' | sed -e 's/<\w*>'//g | sed -e 's/<\/\w*>'//g)
        if [ "$BUILD_MODE" = "DEBUG" ]
        then
            package_name="$pkg_name-dbg"
        fi
        sed -i "s/$pkg_name/$package_name/g" ./debian/install
        sed -i "s/$pkg_name/$package_name/g" ./debian/postinst
        
        sed -i "s/$ROS_DISTRO_ANCHOR/$ROS_DISTRO/g" ./debian/install
        sed -i "s/$ROS_DISTRO_ANCHOR/$ROS_DISTRO/g" ./debian/postinst

        echo -e "\033[0;33mComponent contains movai metadata. Incorporating it in deb.\033[0m"
    else
        echo -e "\033[0;33mNo movai metadata detected.\033[0m"
        rm -f ./debian/install
        rm -f ./debian/postinst
    fi
}

function overwrite_control_debug_package_name(){
    anchor=$(cat debian/control | grep Package:)
    new_package_name="$anchor-dbg"
    sed -i "s/$anchor/$new_package_name/g" debian/control
    
    anchor=$(cat debian/control | grep Source:)
    new_package_name="$anchor-dbg"
    sed -i "s/$anchor/$new_package_name/g" debian/control

    sed -i "s/$pkg_name/$pkg_name-dbg/g" debian/changelog
}
            

function overwrite_rules_build_mode(){

    sed -i 's/DEB_CXXFLAGS_MAINT_APPEND=-DNDEBUG/DEB_CXXFLAGS_MAINT_APPEND=-DNDEBUG -O3 -s/g' debian/rules
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
    if [ -n "$result" ]
    then
        IS_ROS_META_PKG=0
    fi
    
}

function get_unmet_dependencies(){
        result=$(( dpkg-checkbuilddeps ) 2>&1)
        ANCHOR="dpkg-checkbuilddeps: error: Unmet build dependencies: "
        dependencies=$(echo "$result" | sed "s/$ANCHOR//g") 
        UNMET_DEPENDENCY_LIST=($(echo $dependencies | tr ' ' "\n"))
}

function install_generated_dependencies(){
        STDERR_TMP_INSTALL_FILE="/tmp/$pkg_name-install-dep.log"

        sudo apt-get update
        get_unmet_dependencies
        for depend in "${UNMET_DEPENDENCY_LIST[@]}"
        do
            show_result=$(( apt show -a "$depend=${MOVAI_PACKAGE_VERSION}" ) 2>&1)

            package_exists=$(echo "$show_result" | grep 'was not found')

            if [ -z "$package_exists" ]
            then
                echo -e "\033[0;33mInstallting dependency $depend.\033[0m"
                show_result=$(( sudo apt install -y "$depend=${MOVAI_PACKAGE_VERSION}" ) 2> $STDERR_TMP_INSTALL_FILE)

                cat $STDERR_TMP_INSTALL_FILE
            fi

        done
}

function check_if_package_ignored(){

    ignoreFiles=("AMENT_IGNORE" "CATKIN_IGNORE" "COLCON_IGNORE")
    found=0
    for ignoreFile in ${ignoreFiles[@]}; do
        test -f "$ignoreFile"
        result=$?
        ((found=found+result))
    done

    IGNORE_PACKAGE="true"
    if  [ ${#ignoreFiles[@]} -eq $found ]
    then
        IGNORE_PACKAGE="false"
    fi

}

function strip_replaces_in_package(){
    package_path="./package.xml"
       
    placeholder="$(grep "replace" $package_path)"
    if [ -n "$placeholder" ]
    then
        sed -i "s#$placeholder##g" $package_path
    fi
    
}

# function to generate the deb of a ros component in a given path
function generate_package(){

    SUB_COMPONENT_DIR=$1

    cd "${SUB_COMPONENT_DIR}"
    check_if_package_ignored

    if [ ${IGNORE_PACKAGE} = "true" ];
    then
        SKIPPED_DEB_BUILDS+=("$SUB_COMPONENT_DIR")
        printf "Skipping ros project in $SUB_COMPONENT_DIR.\n"
        return
    else
        printf "Packaging ros project in $SUB_COMPONENT_DIR.\n"
    fi

    
    if [ $STRIP_REPLACES = "true" ];
    then
        strip_replaces_in_package
    fi


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
        if [ "$BUILD_MODE" = "DEBUG" ]
        then
            overwrite_control_debug_package_name
            pkg_name="$pkg_name-dbg"
        fi
        pkg_log_TMP_FILE="/tmp/$pkg_name-build.log"

        # overwrite control auto discovery of architecture to "all".
        overwrite_control_architecture

        get_unmet_dependencies


        if [ ${#UNMET_DEPENDENCY_LIST[@]} -gt 0 ]
        then
            install_generated_dependencies
        fi

        if [ "$BUILD_MODE" = "RELEASE" ]
        then
            overwrite_rules_build_mode
        fi

        dpkg-buildpackage -nc -d -b -rfakeroot -us -uc -tc 2> $pkg_log_TMP_FILE

        reason_identified=$(cat $pkg_log_TMP_FILE | grep "$FAILURE_DEBPACK_MISSING_DEPENDENCY")

        if [ -n "$reason_identified" ]
        then
            printf "Failure packaging deb: $reason_identified. \n Postponing packaging for possible dependencies to be generated.\n"
            FAILED_DEB_BUILDS+=("$SUB_COMPONENT_DIR")
            rm -rf debian
            rm -rf obj*
        else
            deb_found=$(find -L ../ -name "${pkg_name}_${MOVAI_PACKAGE_VERSION}*.deb")
            
            if [ ! "$deb_found" ]
            then
                # print failure
                echo -e "\e[31mFailed during packaging :\033[0m"
                cat $pkg_log_TMP_FILE
                set -e 
                exit 1
            fi

            local_publish $pkg_name $deb_found

            mv $(find -L ../ -name "${pkg_name}_${MOVAI_PACKAGE_VERSION}*.deb") .
            rosdep update
        fi


    else
        reason_identified=$(cat $STDERR_TMP_FILE | grep "$FAILURE_ROSDEP_MISSING_DEPENDENCY")

        if [ -n "$reason_identified" ]
        then
            printf "Failure generating deb metadata: $reason_identified. \n Postponing packaging for possible dependencies to be generated.\n"
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

SKIPPED_DEB_BUILDS=()
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
echo -e "\033[0;36mSkipped packages: ${#SKIPPED_DEB_BUILDS[@]}\033[1;33m"
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

