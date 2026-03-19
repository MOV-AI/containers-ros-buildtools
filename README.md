## Docker ros-buildtools Image

Docker image for building, testing, and packaging ROS applications. Supports ROS 1 (Noetic) and ROS 2 (Humble).

| Distro   | ROS Version | Python |
|----------|-------------|--------|
| `noetic`  | ROS 1       | 3.8    |
| `humble`  | ROS 2       | 3.10   |

## Building

**Noetic (ROS 1):**
```bash
docker build --pull -t ros-buildtools:noetic -f noetic/Dockerfile .
```

**Humble (ROS 2):**
```bash
docker build --pull -t ros-buildtools:humble -f humble/Dockerfile .
```

### Build Arguments

- `MOVAI_ENV`: Environment designation (default: develop)
- `MOVAI_BRANCH`: GitHub branch (default: develop)
- `MOBROS_VERSION`: mobros CLI version (default: 2.1.1.6)
- `MOBTEST_VERSION`: mobtest version (default: 0.0.2.2)


```bash
docker build --pull \
  --build-arg MOVAI_ENV=develop \
  --build-arg MOVAI_BRANCH=develop \
  --build-arg MOBROS_VERSION=2.1.1.6 \
  --build-arg MOBTEST_VERSION=0.0.2.2 \
  -t ros-buildtools:noetic \
  -f noetic/Dockerfile .
```

## Getting the Build Script

Download the automated build script:

```bash
# This will change with the first DeployOnMerge -> s3://movai-scripts/ros-build.bash
wget https://movai-scripts.s3.amazonaws.com/ros-build2.bash 
chmod +x ros-build2.bash
```

## Usage

Run the script from your workspace directory. The script will build and package the code in that directory:

```bash
cd /path/to/your/ros/packages
/path/to/ros-build2.bash
```

Example:
```bash
cd ~/movai_ros2_packages
~/containers-ros-buildtools/ros-build2.bash
```

The script will start a container, install dependencies, build packages, and generate .deb files.

**Manual usage (docker):**

Interactive shell:
```bash
docker run -it -v $(pwd):/workspace ros-buildtools:humble /bin/bash
```

Build packages directly:
```bash
docker run --rm -v $(pwd):/workspace ros-buildtools:humble bash -c "\
  mobros build --workspace=/workspace && \
  mobros pack --workspace=/workspace --mode release
"
```
