#!/bin/bash
# ============================================================================
## Copyright 2026 Mov AI                                                       
#
## This script mimics the ROS pipeline behavior
#
## Usage: wget -qO - <url> | bash -s - [OPTIONS]
## Or: bash ros-build.bash [OPTIONS]
# ============================================================================

set -e


# Color Definitions
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'


# Logging Functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_debug() {
    if [[ "$DEBUG" -eq 1 ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}


# Default Configuration
SCRIPT_VERSION="0.1.0"
ROS_DISTRO="humble"
WORKSPACE_PATH="$(pwd)"
KEEP_CONTAINER=0
DEBUG=0
HELP_SHOWN=0
# Versions
MOBROS_VERSION="2.1.1.6"
MOBTEST_VERSION="0.0.2.2"

# Container configuration
IN_CONTAINER_MOUNT_POINT="/__w/workspace/src"
CONTAINER_ID=""


# Help Function
show_help() {
    cat << EOF


====================== MOV.AI ROS BUILD TOOL ======================

> Usage: wget -qO - <url> | bash -s - [OPTIONS]
   or: bash ${0##*/} [OPTIONS]

> Description:
  Build ROS1 or ROS2 packages using the mobros.

> Options:
  -d, --distro DISTRO    ROS distribution to use.
                         Supported: humble & noetic
                         Default: ${ROS_DISTRO}

  -w, --workspace PATH   Path to the ROS repository/workspace.
                         Default: Current directory ($(pwd))

  -k, --keep             DEBUG MODE: Keep the container running if build fails.
                         Useful for troubleshooting. Default: remove on any outcome

  --debug                Enable debug output. Default: disabled

  -h, --help             Show this help message and exit.

> Examples:
  # Build with default settings (humble in current directory)
  bash ros-build.bash

  # Build with noetic in a specific directory
  bash ros-build.bash -d noetic -w /path/to/workspace

  # Download and build in one command
  wget -qO - https://movai-scripts.s3.amazonaws.com/ros-build.bash | bash -s - --distro humble

  # Keep container for debugging
  bash ros-build.bash --keep -d humble

===================================================================

EOF
    HELP_SHOWN=1
    exit 0
}


# Validation Functions
validate_distro() {
    local distro=$1
    local valid_distros=("humble" "noetic")
    
    for valid in "${valid_distros[@]}"; do
        if [[ "$distro" == "$valid" ]]; then
            return 0
        fi
    done
    
    log_err "Unsupported ROS distribution: $distro"
    log_err "Supported distributions: ${valid_distros[*]}"
    exit 1
}

validate_workspace() {
    local workspace=$1
    
    if [[ ! -d "$workspace" ]]; then
        log_err "Workspace path does not exist: $workspace"
        exit 1
    fi
    
    if [[ ! -w "$workspace" ]]; then
        log_err "No write permission for workspace: $workspace"
        exit 1
    fi
    
    log_debug "Workspace validated: $workspace"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_err "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_err "Docker daemon is not running or user lacks permissions"
        log_err "Try: sudo usermod -aG docker \$USER"
        exit 1
    fi
    
    log_debug "Docker is available"
}

check_docker_image() {
    local image=$1
    
    if ! docker image inspect "$image" &> /dev/null; then
        log_warn "Docker image not found: $image"
        log_warn "Attempting to pull the image..."
        
        if ! docker pull "$image"; then
            log_err "Failed to pull Docker image: $image"
            log_err "Please build the image with: docker build -t $image ."
            exit 1
        fi
    fi
    
    log_debug "Docker image available: $image"
}


# Argument Parsing
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--distro)
                ROS_DISTRO="${2:-}"
                if [[ -z "$ROS_DISTRO" ]]; then
                    log_err "Option $1 requires an argument"
                    exit 1
                fi
                shift 2
                ;;
            -w|--workspace)
                WORKSPACE_PATH="${2:-}"
                if [[ -z "$WORKSPACE_PATH" ]]; then
                    log_err "Option $1 requires an argument"
                    exit 1
                fi
                shift 2
                ;;
            -k|--keep)
                KEEP_CONTAINER=1
                shift
                ;;
            --debug)
                DEBUG=1
                shift
                ;;
            -h|--help)
                show_help
                ;;
            *)
                log_err "Unknown option: $1"
                show_help
                ;;
        esac
    done
}


# Cleanup Function
cleanup() {
    local exit_code=$?
    
    if [[ -n "$CONTAINER_ID" ]]; then
        if [[ $exit_code -eq 0 ]] || [[ "$KEEP_CONTAINER" -eq 0 ]]; then
            log_info "Cleaning up container: ${CONTAINER_ID:0:12}"
            docker rm -f "$CONTAINER_ID" &> /dev/null || true
        else
            log_warn "Container kept for debugging: $CONTAINER_ID"
            log_warn "Clean up manually with: docker rm -f $CONTAINER_ID"
        fi
    fi
    
    if [[ "$HELP_SHOWN" -eq 0 ]]; then
        if [[ $exit_code -eq 0 ]]; then
            log_info "Build completed successfully!"
        else
            log_err "Build failed with exit code: $exit_code"
        fi
    fi
    
    return $exit_code
}

trap cleanup EXIT


# Build Execution
run_build() {
    log_info "Starting ROS build process version $SCRIPT_VERSION..."
    log_info "Configuration:"
    log_info "  - ROS Distribution: $ROS_DISTRO"
    log_info "  - Workspace: $WORKSPACE_PATH"
    log_info "  - Mobros Version: $MOBROS_VERSION"
    log_info "  - Mobtest Version: $MOBTEST_VERSION"
    
    # Validate inputs
    validate_distro "$ROS_DISTRO"
    validate_workspace "$WORKSPACE_PATH"
    check_docker
    
    local docker_image="ros-buildtools:${ROS_DISTRO}"
    check_docker_image "$docker_image"
    
    # Start container
    log_info "Starting Docker container..."
    CONTAINER_ID=$(docker run -td \
        -v "$(cd "$WORKSPACE_PATH" && pwd)":$IN_CONTAINER_MOUNT_POINT \
        "$docker_image") || {
        log_err "Failed to start Docker container"
        exit 1
    }
    log_debug "Container started: ${CONTAINER_ID:0:12}"
    
    # Execute build commands
    log_info "Executing build commands in container..."
    
    docker exec -t "$CONTAINER_ID" bash -c "
        set -e
        
        # Install build tools
        echo '[1/6] Installing build tools...'
        python3 -m pip install -i https://artifacts.cloud.mov.ai/repository/pypi-edge/simple \
            --extra-index-url https://pypi.org/simple \
            mobros==${MOBROS_VERSION} --ignore-installed
        
        python3 -m pip install mobtest==${MOBTEST_VERSION} --ignore-installed
        
        # Setup workspace
        echo '[2/6] Setting up workspace...'
        mkdir -p /opt/mov.ai/user/cache/ros/src/
        ln -s ${IN_CONTAINER_MOUNT_POINT}/* /opt/mov.ai/user/cache/ros/src/ || true
        
        export MOVAI_OUTPUT_DIR=${IN_CONTAINER_MOUNT_POINT}/packages
        export PATH=/opt/mov.ai/.local/bin:\$PATH
        
        # Validate packages
        echo '[3/6] Validating packages...'
        mobtest repo \"${IN_CONTAINER_MOUNT_POINT}\"
        
        # Raise packages
        echo '[4/6] Raising packages...'
        mobros raise --workspace=\"${IN_CONTAINER_MOUNT_POINT}\"
        
        # Install build dependencies
        echo '[5/6] Installing build dependencies...'
        sudo mobros install-build-dependencies --workspace=\"${IN_CONTAINER_MOUNT_POINT}\"
        
        # Build packages
        echo '[6/6] Building and packing packages...'
        mobros build
        mobros pack --workspace=\"${IN_CONTAINER_MOUNT_POINT}\" --mode release
    " || {
        log_err "Build execution failed"
        exit 1
    }
}


# Main Entry Point
main() {
    log_info "MOV.AI ROS Build Tool"
    
    parse_arguments "$@"
    run_build
}

main "$@"

