* AX.25 Packet BBS

Setup BBS with 1200 baud AFSK on 2M or 70cm FM amateur radio, using
the BTECH UV-PRO radio with bluetooth KISS TNC.

** Prep Raspberry Pi OS lite aarch64 

```
sudo apt update
sudo apt upgrade
sudo apt install -y ax25-tools ax25-apps expect git

git clone https://github.com/EnigmaCurry/bbs.git ~/bbs
```

** Configure your callsign + station ID

```
MY_CALLSIGN=AI7XP-1

echo "${MY_CALLSIGN}" | tee ~/bbs/my_callsign.txt
```

** Configure AX.25 ports

```
read -r MY_CALLSIGN < ~/bbs/my_callsign.txt
echo "radio    ${MY_CALLSIGN}    1200    255    2    BTECH UV-PRO" \
    | sudo tee /etc/ax25/axports
```

** Pair radio bluetooth

```
~/bbs/bt_pair.exp
```

** Bind rfcomm device

```
read -r MAC_ADDRESS < ~/bbs/mac_address.txt
sudo rfcomm bind /dev/rfcomm0 ${MAC_ADDRESS} 1
```

** Attach to the KISS TNC

```
sudo kissattach /dev/rfcomm0 radio
```

** Verify `ax0` device exists

```
$ ip link
...
4: ax0: <BROADCAST,UP,LOWER_UP> mtu 255 qdisc pfifo_fast state UNKNOWN group default qlen 10
    link/ax25 AI7XP-1 brd QST-0 permaddr LINUX-1
```


** Enable ax25d

```
read -r MY_CALLSIGN < ~/bbs/my_callsign.txt

cat <<EOF | sudo tee /etc/ax25/ax25d.conf
[${MY_CALLSIGN}]
default * * * * * * *  root  /usr/local/bin/bbs.py BBS ${MY_CALLSIGN} %d %S
EOF
```
