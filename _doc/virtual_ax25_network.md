```
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
sleep 1 && \
ls -lha ${KISSTMP:-/tmp/kiss}
```

```
sudo podman build -t aprs_listen ~/qos/aprs_listen && \
sudo podman run --rm -it --privileged \
     -v /tmp/kiss/kiss1:/tmp/rfcomm0 \
     -v /dev/pts:/dev/pts:Z \
     --group-add=$(getent group tty | cut -d: -f3) \
     aprs_listen
```
