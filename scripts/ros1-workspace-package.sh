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


#Colors
RED='\e[31m'
PURPLE='\033[1;35m'
WHITE='\033[0m'
GREEN='\033[0;32m'
BROWN='\033[0;33m'
CYAN='\033[0;36m'

BOLD_YELLOW='\033[1;33m'
BOLD_GREEN='\033[1;32m'


function clear_local_apt_cache(){
    rm -f ${LOCAL_REGISTRY}/*.deb
}

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

    # check if rosdep can resolve, and if not, rosdep update
    rosdep resolve $ros_pkg_name

    if [ $? -ne 0 ]
    then
        rosdep update
    fi

}


function rosify_package_name(){

    name_section=$(cat ./package.xml | grep "<name>.*<\/name>")
    pkg_name=$(echo $name_section | sed 's/ //g' | sed -e 's/<\w*>'//g | sed -e 's/<\/\w*>'//g)
    #replace - with _. ros naming conventions
    ros_pkg_name=$(echo "$pkg_name" | sed 's/_/-/g')
    DEBIAN_PACKAGE_NAME="ros-${ROS_DISTRO}-$ros_pkg_name"

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
        echo -e "${RED}Still using movai_metadata folder which is no longer acceptable. Please change to metadata.${WHITE}"
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

        echo -e "${BROWN}Component contains movai metadata. Incorporating it in deb.${WHITE}"
    else
        echo -e "${BROWN}No movai metadata detected.${WHITE}"
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

function overwrite_compat_file(){
    desired_compat="10"

    anchor=$(cat debian/compat)

    if [ -z "$anchor" ]; then
        echo "$desired_compat" >>debian/compat
    fi
    
    sed -i "s/$anchor/$desired_compat/g" debian/compat

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

    PKG_INSTALL_LIST=""
    PKGS_FOUND=0
    for depend in "${UNMET_DEPENDENCY_LIST[@]}"
    do
        if [[ " ${WORKSPACE_PACKAGES[*]} " =~ " ${depend} " ]]; then

            PUBLISHED_PACKAGES="$(find -L ${LOCAL_REGISTRY} -name "*.deb" | awk '{ print length, $0 }' | sort -rn | cut -d" " -f2-)"
            
            for PUB_PKG in $PUBLISHED_PACKAGES; do
                package_found=$(dpkg --info "$PUB_PKG" | grep "Package: $depend$")

                if [ -n "$package_found" ]
                then
                    PKG_INSTALL_LIST="$PKG_INSTALL_LIST $PUB_PKG"
                    ((PKGS_FOUND=PKGS_FOUND+1))
                fi
            done

        fi

    done

    INSTALL_GENERATED_DEP_RETURN_CODE=1
    if [ $PKGS_FOUND -eq ${#UNMET_DEPENDENCY_LIST[@]} ]
    then
        echo -e "${BROWN}Installting dependencies $PKG_INSTALL_LIST."
        sudo mobros install $PKG_INSTALL_LIST -y
        echo -e "${WHITE}"
        INSTALL_GENERATED_DEP_RETURN_CODE=0

    fi
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


function register_local_package(){
    SUB_COMPONENT_DIR=$1

    cd "${SUB_COMPONENT_DIR}"
    check_if_package_ignored

    if [ ${IGNORE_PACKAGE} = "true" ];
    then
        return
    else
        echo -e "${BROWN}Subscribing local package $SUB_COMPONENT_DIR."
    fi

    rosify_package_name
    WORKSPACE_PACKAGES+=("$DEBIAN_PACKAGE_NAME")

}

# function to generate the deb of a ros component in a given path
function generate_package(){

    SUB_COMPONENT_DIR=$1
    echo -e "${WHITE}\n\n\n\n\n"

    cd "${SUB_COMPONENT_DIR}"
    check_if_package_ignored

    if [ ${IGNORE_PACKAGE} = "true" ];
    then
        SKIPPED_DEB_BUILDS+=("$SUB_COMPONENT_DIR")
        echo -e "${BROWN}Skipping ros project in $SUB_COMPONENT_DIR."
        return
    else
        echo -e "${GREEN}---------------------------------------"
        echo -e "${GREEN}Packaging ros project in $SUB_COMPONENT_DIR"
        echo -e "${GREEN}---------------------------------------${WHITE}"
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
        dch -b -v "${MOVAI_PACKAGE_VERSION}" "Auto created package version: ${MOVAI_PACKAGE_VERSION}" < /dev/null

        pkg_name="$(dpkg-parsechangelog -S Source)"
        if [ "$BUILD_MODE" = "DEBUG" ]
        then
            overwrite_control_debug_package_name
            pkg_name="$pkg_name-dbg"
        fi
        pkg_log_TMP_FILE="/tmp/$pkg_name-build.log"

        # overwrite control auto discovery of architecture to "all".
        overwrite_control_architecture

        # overwrite compat file to 10
        overwrite_compat_file

        get_unmet_dependencies

        if [ ${#UNMET_DEPENDENCY_LIST[@]} -gt 0 ]
        then
            echo -e "${BROWN}Missing the following dependencies:"
            for dep_elem in "${UNMET_DEPENDENCY_LIST[@]}"; do
                echo -e "${BROWN} $dep_elem${WHITE}"
            done
            install_generated_dependencies

            if [ $INSTALL_GENERATED_DEP_RETURN_CODE -ne 0 ]
            then
                FAILED_DEB_BUILDS+=("$SUB_COMPONENT_DIR")
                rm -rf debian
                rm -rf obj*

                echo -e "${BROWN}Runtime dependencies not yet generated. Skipping packaging for now.${WHITE}"
                return
            fi

        fi

        if [ "$BUILD_MODE" = "RELEASE" ]
        then
            overwrite_rules_build_mode
        fi

        dpkg-buildpackage -nc -d -b -rfakeroot -us -uc -tc 2> $pkg_log_TMP_FILE

        reason_identified=$(cat $pkg_log_TMP_FILE | grep "$FAILURE_DEBPACK_MISSING_DEPENDENCY")

        if [ -n "$reason_identified" ]
        then
            echo -e "${RED}Failure packaging deb: $reason_identified. \n Postponing packaging for possible dependencies to be generated.${WHITE}"
            FAILED_DEB_BUILDS+=("$SUB_COMPONENT_DIR")
            rm -rf debian
            rm -rf obj*
        else
            deb_found=$(find -L ../ -name "${pkg_name}_${MOVAI_PACKAGE_VERSION}*.deb")
            
            if [ ! "$deb_found" ]
            then
                # print failure
                echo -e "${RED}Failed during packaging :${WHITE}"
                cat $pkg_log_TMP_FILE
                set -e 
                exit 1
            fi

            local_publish $pkg_name $deb_found

            mv $(find -L ../ -name "${pkg_name}_${MOVAI_PACKAGE_VERSION}*.deb") .
        fi


    else
        reason_identified=$(cat $STDERR_TMP_FILE | grep "$FAILURE_ROSDEP_MISSING_DEPENDENCY")

        if [ -n "$reason_identified" ]
        then
            echo -e "${RED}Failure generating deb metadata: $reason_identified. \n Postponing packaging for possible dependencies to be generated.${WHITE}"
            FAILED_DEB_BUILDS+=("$SUB_COMPONENT_DIR")
        else
            echo -e "${RED}Failed during instantiation of meta data before packaging :${WHITE}"
            reason_identified=$(cat $STDERR_TMP_FILE)

            echo -e "${RED}$reason_identified.${WHITE}"
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

clear_local_apt_cache
rosdep update
sudo apt-get update
find_main_package_version

WORKSPACE_PACKAGES=()
SUB_COMPONENTS="$(dirname $(find -L ${MOVAI_PACKAGING_DIR} -name package.xml) | awk '{ print length, $0 }' | sort -rn | cut -d" " -f2-)"
for SUB_COMPONENT_PATH in $SUB_COMPONENTS; do
    register_local_package "$SUB_COMPONENT_PATH"
done

SKIPPED_DEB_BUILDS=()
SUB_COMPONENTS="$(dirname $(find -L ${MOVAI_PACKAGING_DIR} -name package.xml) | awk '{ print length, $0 }' | sort -rn | cut -d" " -f2-)"
for SUB_COMPONENT_PATH in $SUB_COMPONENTS; do
    generate_package "$SUB_COMPONENT_PATH"
done

max_attempts=5
for (( i=1; i<=$max_attempts; i++ ))
do  
    if [ ${#FAILED_DEB_BUILDS[@]} -eq 0 ]; then
        break
    fi
    echo -e "${RED}-------------------------------------------------"
    echo -e "${RED}Attempt number $i on resolving dependencies. Re-iterating the projects that have been postponed."
    echo -e "${RED}-------------------------------------------------"

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
obtained_pkgs=$(find -L ${LOCAL_REGISTRY} -name "*.deb" | wc -l)

echo -e "${PURPLE}============================================${WHITE}"
echo -e "${CYAN}ROS-WORKSPACE-PACKAGE SCRIPT SUMMARY:"
echo -e "${CYAN}Generated packages: ${BOLD_YELLOW}$obtained_pkgs ${CYAN}of ${BOLD_GREEN}$expected_pkgs"
echo -e "${CYAN}Skipped packages: ${#SKIPPED_DEB_BUILDS[@]}${BOLD_YELLOW}"
echo -e "${PURPLE}============================================${WHITE}"

#copy to output dir if needed
if [ -n "${MOVAI_OUTPUT_DIR}" ];
then
    if [ ! -d "${MOVAI_OUTPUT_DIR}" ];
    then
        mkdir -p "${MOVAI_OUTPUT_DIR}"
    fi
    echo "Copying debs to ${MOVAI_OUTPUT_DIR}"

    find -L "${LOCAL_REGISTRY}" -type f -name '*.deb' -exec cp {} "${MOVAI_OUTPUT_DIR}" \;

fi

skipped=${#SKIPPED_DEB_BUILDS[@]}
total_expected=$((expected_pkgs-skipped))

if [[ $obtained_pkgs < $total_expected ]];
then
    echo -e "${RED}Failed to generate all packages. Expected $total_expected but only generated $obtained_pkgs.${WHITE}"
    set -e
     exit 1
fi
