# Initialize ROS1
trap on_control_c INT

function on_control_c() {
    echo "User interrupt"
    exit 1
}

source "/usr/local/lib/movai-packaging.bash"

# Initialize ROS1
source "/opt/ros/${ROS_DISTRO}/setup.bash"

set -x

rosdep update

printf "Preparing Mov.ai ROS packages\n"

mkdir -p /tmp/cache

if [ ! -d /tmp/cache/src ]; then
    printf "Initialiazing ROS1 Workspace ...\n"
    wstool init /tmp/cache/src
fi

PACKAGE=/tmp/movai.rosinstall

printf "Preparing Mov.ai ROS1 packages\n"
wstool merge -t /tmp/cache/src ${PACKAGE}
wstool update -t /tmp/cache/src
rosdep install -y --from-paths /tmp/cache/src --ignore-src --rosdistro ${ROS_DISTRO} -r
rm --preserve-root ${PACKAGE}

pushd /opt/mov.ai/workspaces/MOVAI_ROS1 >/dev/null
if [ ! -d src ]; then
    printf "Initialiazing Mov.ai ROS1 Workspace ...\n"
    wstool init src
fi

if [ -z "$CMAKE_ARGS" ]; then
    CMAKE_ARGS='--cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS_RELEASE=-s -DCMAKE_CXX_FLAGS_RELEASE=-s'
fi

BUILD_LIMITS="${BUILD_LIMITS:--j2 -l2 --mem-limit 50%}"
BUILD_ARGS="${BUILD_LIMITS} -DPYTHON_VERSION=${PYTHON_VERSION:-3.6}"

printf "Configuring Mov.ai ROS1 Workspace with args:\n"
printf "\t env: %s\n" "${MOVAI_ENV}"
printf "\t cmake: %s\n" "${CMAKE_ARGS}"
wstool update -t src
catkin config \
    --extend /opt/ros/${ROS_DISTRO} --install --merge-install \
    --source-space /tmp/cache/src \
    --devel-space /tmp/cache/devel \
    --log-space /tmp/cache/logs \
    --build-space /tmp/cache/build \
    --install-space /opt/mov.ai/workspaces/MOVAI_ROS1 \
    ${CMAKE_ARGS}

printf "Building Mov.ai ROS1 Workspace with args:\n"
printf "\t args: %s\n" "${BUILD_ARGS}"
catkin build ${BUILD_ARGS}
popd >/dev/null

# If we are in prod and qa, clean-up keys and .git repositories
# On non development environments we clean up everything related to the build env
rm -rf /tmp/cache
