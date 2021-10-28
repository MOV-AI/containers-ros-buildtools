#!/bin/bash
env=$1


CUSTOM_GLOBAL_YAML_BASE="https://artifacts.cloud.mov.ai/repository/movai-applications"
GLOBAL_YAML_FILE_DEV=$CUSTOM_GLOBAL_YAML_BASE"/develop/rosdep/rosdep.yaml"
GLOBAL_YAML_FILE_PROD=$CUSTOM_GLOBAL_YAML_BASE"/prod/rosdep/rosdep.yaml"

if  [ "$env" == "DEV" ]; then
  GLOBAL_YAML_FILE=$GLOBAL_YAML_FILE_DEV
fi

if  [ "$env" == "PROD" ]; then
  GLOBAL_YAML_FILE=$GLOBAL_YAML_FILE_PROD
fi


GLOBAL_ROSDEP_SOURCELIST_FILE="/etc/ros/rosdep/sources.list.d/20-default.list"
ROSDEP_YAML_PATH="/usr/local/rosdep"
ROSDEP_YAML_FILE="$ROSDEP_YAML_PATH/ros-pkgs.yaml"


if [[ -n "${GLOBAL_YAML_FILE}" ]]; then

  if ! grep -q "$CUSTOM_GLOBAL_YAML_BASE" "$GLOBAL_ROSDEP_SOURCELIST_FILE"
  then
    printf "# Global yaml for published ros packages\
        \nyaml $GLOBAL_YAML_FILE \n" >> $GLOBAL_ROSDEP_SOURCELIST_FILE
  else
    if  [ $env == "DEV" ]; then
      sed -i "s|$GLOBAL_YAML_FILE_PROD|$GLOBAL_YAML_FILE_DEV|g" $GLOBAL_ROSDEP_SOURCELIST_FILE
      echo "switched to DEV"
    fi

    if  [ $env == "PROD" ]; then
      sed -i "s|$GLOBAL_YAML_FILE_DEV|$GLOBAL_YAML_FILE_PROD|g" $GLOBAL_ROSDEP_SOURCELIST_FILE
      echo "switched to PROD"
    fi

  fi 
fi


if  [ "$env" == "LOCAL" ]; then
  if ! grep -q "$ROSDEP_YAML_FILE" "$GLOBAL_ROSDEP_SOURCELIST_FILE"
  then
    printf "# local yaml for local generated ros packages\
          \nyaml file://${ROSDEP_YAML_FILE} \n" >> $GLOBAL_ROSDEP_SOURCELIST_FILE

    echo "Enabled local rosdep yaml"
  fi
fi
