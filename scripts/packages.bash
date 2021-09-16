# Add user to sudoers

SUDO_COMMANDS=(
    ${APP_PATH}/async_movaicore.py
    /usr/bin/dpkg
    /usr/bin/make
    /usr/bin/bluetoothctl
)

# Setup available sudo commands for user movai
[ -f /etc/sudoers.d/movai ] || touch /etc/sudoers.d/movai

for SUDO_COMMAND in ${SUDO_COMMANDS[@]}; do
    echo "%sudo ALL=(ALL) NOPASSWD:SETENV: ${SUDO_COMMAND}" >> /etc/sudoers.d/movai
done

{
    echo 'Defaults  env_keep += "ROS_DISTRO"'
    echo 'Defaults  env_keep += "MOVAI_ENV"'
    echo 'Defaults  env_keep += "MOVAI_HOME"'
    echo 'Defaults  env_keep += "PYTHON_VERSION"'
    echo 'Defaults  env_keep += "ROS1_MOVAI_WS"'
    echo 'Defaults  env_keep += "ROS2_MOVAI_WS"'
    echo 'Defaults  env_keep += "ROS1_USER_WS"'
    echo 'Defaults  env_keep += "ROS2_USER_WS"'
    echo 'Defaults  env_keep += "MOVAI_USERSPACE"'
} >> /etc/sudoers.d/movai


# Run movai-ros-provision as movai user
sudo -i -u movai /tmp/movai-ros-provision.sh

# fix permission
chown movai:movai -R ${MOVAI_HOME}
