## Docker ros-buildtools Image

Docker image for building, testing, and packaging ROS applications. Supports ROS 1 (Noetic) and ROS 2 (Humble).

| Distro   | ROS Version | Python |
|----------|-------------|--------|
| `noetic`  | ROS 1       | 3.8    |
| `humble`  | ROS 2       | 3.10   |

## Building

**Noetic (ROS 1):**
```bash
docker build --pull -t ros-buildtools-noetic:local -f noetic/Dockerfile .
```

**Humble (ROS 2):**
```bash
docker build --pull -t ros-buildtools-humble:local -f humble/Dockerfile .


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
  -t ros-buildtools-noetic:local \
  -f noetic/Dockerfile .
```

## Getting the Build Script

The production-ready build script is automatically published to S3 and versioned.

**Latest version:**
```bash
wget -qO ros-build.bash https://movai-scripts.s3.amazonaws.com/movai-scripts/ros-build.bash
chmod +x ros-build.bash
```

**Specific version:**
```bash
# Replace VERSION with the desired version (e.g., 0.1.0)
wget -qO ros-build.bash https://movai-scripts.s3.amazonaws.com/movai-scripts/ros-build_VERSION.bash
chmod +x ros-build.bash
```

**One-liner download and execute:**
```bash
wget -qO - https://movai-scripts.s3.amazonaws.com/movai-scripts/ros-build.bash | bash -s - --help
```

## Usage

Run the script from your workspace directory:

```bash
cd /path/to/your/ros/packages
ros-build.bash
```

For help and available options:

```bash
ros-build.bash -h
```

**Common options:**
- `-d, --distro` - ROS distribution (humble, noetic). Default: humble
- `-w, --workspace` - Path to ROS repository. Default: current directory
- `-k, --keep` - Keep container if build fails (debug mode)
- `--debug` - Enable debug output

The script will automatically start a Docker container, validate packages, install dependencies, build, and generate .deb files.

**Manual usage (docker):**

Interactive shell:
```bash
docker run -it -v $(pwd):/workspace ros-buildtools-humble:local /bin/bash
```

Build packages directly:
```bash
docker run --rm -v $(pwd):/workspace ros-buildtools-humble:local bash -c "\
  mobros build --workspace=/workspace && \
  mobros pack --workspace=/workspace --mode release
"
```
