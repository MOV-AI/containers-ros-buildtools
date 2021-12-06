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


MOVAI_PACKAGE_VERSION="${MOVAI_PACKAGE_VERSION:-0.0.0-dirty}"
MOVAI_PACKAGE_RAISE_TYPE="${MOVAI_PACKAGE_RAISE_TYPE:-FULL}"


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

function validate_and_find_main_package(){
    
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

    root_packages="$(find -L . -maxdepth 2 -type f -name 'package.xml'| wc -l)"

    # Catch the: No package.xml found in root ros components (ros components that are in the root of the repo. Ex: ./<my_component>/package.xml).
    if [ $root_packages -eq 0 ]
    then
        echo -e "\e[31mNo packages found at the root level. Without it, mobros can not decide which version to raise (mobros chooses a main package, and his version is the one used for all in the same repository. In case of many packages in the root folder, please create a metapackage.).\033[0m"
        popd > /dev/null
        set -e  
        exit 6
    fi

    packages_xmls="$(find -L . -maxdepth 2 -type f -name 'package.xml')"
    # transform into array
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

    popd > /dev/null
}

function raise_build_version(){

    # store artifact for external tools to know the main package (sed is transforming the relative to full path).
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

}


validate_and_find_main_package

if [ $MOVAI_PACKAGE_RAISE_TYPE == "CI" ]
then
    raise_build_version
    echo -e "\033[0;36mRaised version to \033[1;36m$MOVAI_PACKAGE_VERSION\033[0m"
fi


