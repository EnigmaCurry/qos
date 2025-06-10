#!/bin/bash
set -ex
read -r MAC_ADDRESS < ${HOME}/bbs/mac_address.txt
killall kissattach || true
rfcomm release /dev/rfcomm0 2>/dev/null || true
rfcomm bind /dev/rfcomm0 "${MAC_ADDRESS}" 1
sleep 15
kissattach /dev/rfcomm0 radio
ip link show dev ax0
sleep 15
ip link show dev ax0
echo "The ax0 device still exists after waiting a bit, so it's probably working."
