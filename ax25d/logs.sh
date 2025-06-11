#!/bin/bash
set -e

SERVICE=ax25d
IMAGE=localhost/ax25d
DIRECTORY=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

# Check if container exists
if ! podman container exists "$SERVICE"; then
    echo "Error: Container '$SERVICE' does not exist." >&2
    exit 1
fi

# Check if container is running
STATE=$(podman inspect -f '{{.State.Status}}' "$SERVICE")
if [[ "$STATE" != "running" ]]; then
    echo "Error: Container '$SERVICE' is not running (state: $STATE)." >&2
    exit 1
fi

# Run journalctl inside the container
exec podman exec "$SERVICE" journalctl --unit "$SERVICE" "$@"
