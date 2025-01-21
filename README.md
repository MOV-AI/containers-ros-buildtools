## Docker ros-buildtools image

Docker image used to compile, test and publish our cpp projects. Also has the capabilities to build .deb packages.

## Build

Melodic version :

    docker build --pull -t ros-buildtools:melodic -f melodic/Dockerfile .

Noetic version :

    docker build --pull -t ros-buildtools:noetic -f noetic/Dockerfile .


