#!/bin/bash

set -e

SERVICE=ax25d
IMAGE=localhost/ax25d
DIRECTORY=$(dirname $(realpath ${BASH_SOURCE}))
podman rm -f ${SERVICE}
podman build -t ${IMAGE} ${DIRECTORY}
podman run -d \
       --name ax25d \
       --privileged \
       --network=host \
       --volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
       --volume /etc/ax25:/etc/ax25:ro \
       ${IMAGE}
