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
# - MOVAI_PACKAGE_VERSION (overwrite the version)
# - MOVAI_PACKAGE_RAISE_TYPE
# -   values:
# -     - FULL: use value from MOVAI_PACKAGE_VERSION
# -     - CI: AUTO BUILDID BUMP

MOVAI_PACKAGE_OS="${MOVAI_PACKAGE_OS:-ubuntu}"
MOVAI_PACKAGE_VERSION="${MOVAI_PACKAGE_VERSION:-0.0.0-dirty}"
MOVAI_PACKAGE_RAISE_TYPE="${MOVAI_PACKAGE_RAISE_TYPE:-FULL}"

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

function overwrite_control_architecture(){
    desired_arch="Architecture: all"

    anchor=$(cat debian/control | grep Architecture)

    if [ -z "$anchor" ]; then
        echo "$desired_arch" >>debian/control
    fi
    
    sed -i "s/$anchor/$desired_arch/g" debian/control

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

function boostrap_export_ros_package_xml(){
    package_xml=$1
    echo -e "\033[0;33mInjecting the right repository into the package.xml url attribute\033[0m"
    export_section="\n  <export>\n  <\/export>\n"
    
    anchor="<\/package>"
    sed -i "s/$anchor/$export_section$anchor/g" $package_xml
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

function boostrap_build_version_ros_package_xml(){
    package_xml=$1

    export_section=$(cat $package_xml | grep "<export>")

    if [ ! "$export_section" ]
    then
        boostrap_export_ros_package_xml $package_xml
    fi

    build_version_init=0
    build_version_attr="\n        <build_version>$build_version_init<\/build_version>"
    anchor="<export>"

    sed -i "s/$anchor/$anchor$build_version_attr/g" $package_xml

}

function raise_build_version(){

    pushd ${MOVAI_PACKAGING_DIR} > /dev/null
    nr_packages="$(find -L . -name package.xml | wc -l)"

    # Catch the: No package.xml found anywhere in the repo, despite root level. Nothing to pack.
    if [ $nr_packages -eq 0 ]
    then
        echo -e "\e[31mNo package.xml found in this workspace. Please specify a valid workspace!\033[0m"
        popd > /dev/null
        set -e 
        exit 3
    fi

    root_packages="$(find -L . -name package.xml | grep -c '^.\/[^/]*/package.xml')"

    if [ $root_packages -eq 0 ]
    then
        echo -e "\e[31mNo packages found at the root level. Without it, mobros can not decide which version to raise.\033[0m"
        popd > /dev/null
        set -e  
        exit 6
    fi
    

    packages_xmls="$(find -L . -name package.xml | grep -E '^.\/[^/]*/package.xml')"
    packages_array=($(echo $packages_xmls | tr ' ' "\n"))
    nr_metapackages=0
    main_package=""
    root_level_ros_components=0

    # analyse root level packages. Not analysing sub directories of them! 
    for pkg_path in "${packages_array[@]}"
    do

        is_ros_metapackage $pkg_path
        if [ $IS_ROS_META_PKG -eq 0 ]
        then
            ((nr_metapackages=nr_metapackages+1))
            main_package=$pkg_path
        else
            ((root_level_ros_components=root_level_ros_components+1))
            main_package_candidate=$pkg_path
        fi
    done
    
    # Catch the: Multiple ros metapackages in root level. Becomes impossible to find the main package to raise. Should be only one.
    if [ $nr_metapackages -gt 1 ]
    then
        echo -e "\e[31mMultiple Ros Metapackages found in the root of your repository. You can only have one (found $nr_metapackages).\033[0m"
        popd > /dev/null
        set -e  
        exit 4
    fi

    # Catch the: Multiple ros packages in root level without a ros metapackage. We need a metapackage to identify the main package for raise.
    if [ $root_level_ros_components -gt 1 ] && [ $nr_metapackages -eq 0 ]
    then
        echo -e "\e[31mYou have multiple ros packages in root level without defining a ros metapackage.\033[0m"
        popd > /dev/null
        set -e 
        exit 5
    fi

    # if no ros metapackage was found, and we passed the validations, it means i only have 1 root package and that will be my main for raise.
    if [ $nr_metapackages -eq 0 ]
    then
        main_package=$main_package_candidate
    fi

    # store artifact for external tools to know the main package.
    work_dir=$(pwd)
    main_path=$(echo $main_package | sed "s/\.\///g" )
    echo "$work_dir/$main_path" > "/tmp/main-package.mobrosinfo"


    build_version_section=$(cat $main_package | grep build_version)
    version_section=$(cat $main_package | grep "<version")

    if [ ! "$build_version_section" ]
    then
        boostrap_build_version_ros_package_xml $main_package
        build_version_section=$(cat $main_package | grep build_version)
    fi

    buildid=$(echo $build_version_section | sed 's/ //g' | sed -e 's/<\w*>'//g | sed -e 's/<\/\w*>'//g)

    ((raisedbuildid=buildid+1))
    raised_build_version_section="echo 'echo $build_version_section | sed "s/$buildid/$raisedbuildid/g" | sed -e 's/<\/\w*>'//g'"

    raised_build_version_section="$(echo $build_version_section | sed "s/$buildid/$raisedbuildid/g" | sed -e 's/<\/\w*>'//g)"

    sed -i "s/$(echo $build_version_section | sed -e 's/<\/\w*>'//g)/$raised_build_version_section/g" $main_package

    MOVAI_PACKAGE_VERSION="$(echo "$version_section" | sed 's/ //g' | sed -e 's/<\w*>'//g | sed -e 's/<\/\w*>'//g)-$raisedbuildid"
    popd > /dev/null
}

if [ $MOVAI_PACKAGE_RAISE_TYPE == "CI" ]
then
    raise_build_version
    echo -e "\033[0;36mRaised version to \033[1;36m$MOVAI_PACKAGE_VERSION\033[0m"
fi



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

