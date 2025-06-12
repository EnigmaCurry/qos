#!/bin/bash
set -euo pipefail

COUNT="${COUNT:-3}"
LINK_PREFIX="/tmp/kiss/kiss"
DEVICE="${DEVICE:-}"

# Cleanup old symlinks
for i in $(seq 0 $((COUNT - 1))); do
    rm -f "${LINK_PREFIX}${i}"
done

mkdir -p "$(dirname "$LINK_PREFIX")"

# Create a temporary named pipe to capture startup output
PIPE=$(mktemp -u)
mkfifo "$PIPE"

# Start kissnetd in the background, send stdout to both terminal and pipe
kissnetd -p "$COUNT" > >(tee "$PIPE") &
KISSPID=$!

# Read the line with /dev/pts/X devices from the pipe
while read -r line; do
    if [[ "$line" == /dev/pts/* ]]; then
        read -ra pts_devices <<< "$line"
        break
    fi
done < "$PIPE"

# Clean up the pipe
rm "$PIPE"

# Create symlinks for each /dev/pts/X device
for i in "${!pts_devices[@]}"; do
    ln -sf "${pts_devices[$i]}" "${LINK_PREFIX}${i}"
    chmod 0660 "${pts_devices[$i]}"
    echo "Linked ${pts_devices[$i]} → ${LINK_PREFIX}${i}"
done

# Run socat to connect the real TNC to kiss0
if [[ -n "${DEVICE}" ]]; then
    echo
    set -x
    socat FILE:"$DEVICE",raw,echo=0 FILE:"${LINK_PREFIX}0",raw,echo=0 &
    SOCATPID=$!
    set +x
else
    sleep infinity &
    SOCATPID=$!
fi

# Trap to clean up on exit
cleanup() {
    echo "Stopping..."
    kill "$KISSPID" "$SOCATPID" 2>/dev/null || true
    wait "$KISSPID" "$SOCATPID" 2>/dev/null || true
    for i in $(seq 0 $((COUNT - 1))); do
        rm -f "${LINK_PREFIX}${i}"
    done
}
trap cleanup EXIT

# Wait for both processes
wait "$KISSPID" "$SOCATPID"
