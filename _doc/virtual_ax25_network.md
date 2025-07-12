Start `kissnetd` in a container and create 5 virtual KISS (serial)
devices named:

 * `/tmp/kiss/kiss0`
 * `/tmp/kiss/kiss1`
 * `/tmp/kiss/kiss2`
 * `/tmp/kiss/kiss3`
 * `/tmp/kiss/kiss4`

```
(set -ex
##
## Start kissnetd in a container
##
    COUNT=5
    KISSTMP=/tmp/kiss
    sudo podman build -t kissnetd ~/qos/kissnetd && \
    sudo mkdir -p ${KISSTMP} && \
    sudo podman rm -f kissnetd && \
    sudo podman run --name kissnetd \
        -d --rm --privileged \
        -v ${KISSTMP:-/tmp/kiss}:/tmp/kiss \
        -v /dev/pts:/dev/pts \
        -e COUNT=${COUNT:-5} \
    kissnetd && \
    sudo podman ps --filter name=kissnetd && \
    sleep ${COUNT:-5} && \
    ls -lha ${KISSTMP:-/tmp/kiss}
##
##  Attach AX.25 on the host
##
    KISS_DEVICE=/tmp/kiss/kiss0
    AX25_PORT=kissnet-test
    AX25_PORT_DESCRIPTION="KISSNET TEST"
    HOST_CALLSIGN=N0CALL-3
    ## Create AX.25 port:
    if ! grep -q "^${AX25_PORT}[[:space:]]" /etc/ax25/axports; then
        echo "${AX25_PORT}    ${HOST_CALLSIGN}    1200    255    2    ${AX25_PORT_DESCRIPTION}" | \
           sudo tee -a /etc/ax25/axports
    else
        echo "AX.25 port '${AX25_PORT}' already exists in /etc/ax25/axports"
    fi
    sudo pkill -f "^kissattach ${KISS_DEVICE}" || true
    # Loop through all ax.25 interfaces and delete the old ones
    for iface in $(ip -o link show | awk -F': ' '/^.*: ax[0-9]+/ {print $2}'); do
        info=$(ip link show dev "$iface")
        callsign=$(echo "$info" | awk '/link\/ax25/ {print $2}')
        
        if [[ "$callsign" =~ ^${HOST_CALLSIGN}(-[0-9]+)?$ ]]; then
            echo "Matched $iface with callsign $callsign — removing..."
            sudo ip link set "$iface" down
        fi
    done
    ## Attach the KISS TNC to the AX.25 port:
    sudo kissattach ${KISS_DEVICE} ${AX25_PORT}
    ## Show the list of AX.25 interfaces:
    ip link show | awk -F: '/^[0-9]+: ax[0-9]*/ {print $0}'
## 
## Attach one of kissnetd ports to a container process listening for APRS packets:
##
    sudo podman build -t aprs_listen ~/qos/aprs_listen && \
    sudo podman run --rm -it --privileged \
        -v /tmp/kiss/kiss1:/tmp/rfcomm0 \
        -v /dev/pts:/dev/pts:Z \
        --group-add=$(getent group tty | cut -d: -f3) \
        aprs_listen
)
```

Send an APRS packet from the host and the client should see it:

```
beacon -s -d BBS kissnet-test '::BBS     :Hello from AI7XP!'
```
