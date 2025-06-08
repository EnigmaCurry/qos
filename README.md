# AX.25 Packet BBS

This is a BBS that operates on amateur (ham) radio. No Internet
required!

This is still a work in progress.

## Goal

Setup an electronic bulletin board system (BBS) using a BTECH UV-PRO
amateur radio (HT), which includes a bluetooth KISS TNC that can be
paired and bonded with the Linux bluetooth and AX.25 network stack. A
Raspberry Pi will operate a 1200 baud AFSK BBS service on 2M or 70cm
FM amateur radio. Install an appropriate antenna for the local service
area.

## Prep a Raspberry Pi

 * [Install Raspberry Pi OS 64 bit
   *lite*](https://www.raspberrypi.com/software/) (lite version is for
   creating a server with no desktop).

## Common Setup for all AX.25 peers
### Setup radio

The BTECH UV-PRO (and similar radios) need to be updated to run the
latest firmware. To do this follow these steps:

 * Use an android smartphone and download the BTECH app from the play
   store.

 * On the radio, put it into pairing mode. 
   * Under `Menu`,
     * `General Settings`
       * `Connection`
         * `Pairing` (toggle ON)

 * Open the app and pair with a "Walkie Talkie". 
 * It should prompt you to update the firmware, follow the guidance to
   do so.

Once updated, use the radio menu to setup the TNC:

 * Under Menu
   * `General Settings`
     * `Connection`
       * Find the smartphone you paired earlier, and UNPAIR it, so
         that it won't interfere with your Linux connection.
     * `Signaling Settings`
       * Set the `ID` to your station callsign + id. This setting is
         cosmetic on the radio itself, only so that it's easier to
         identify the radio physically, but this setting is not
         actually used by AX.25 (this will be defined again on the
         Linux side.)
     * `KISS TNC`
       * `Enable KISS TNC` (toggle ON)
   * `Radio Settings`
     * `Power` 
       * Choose high, medium, or low, depending on your range.
     * `Tail Elimination` (toggle OFF)
     * `Digital Mute`
       * Optional, on or off, depending if you like to hear the
       *outgoing* modem sounds.
 
 * Tune the radio to the desired frequency.
 * Turn the radio off and back on.

### Install dependencies

```
sudo apt update
sudo apt upgrade
sudo apt install -y ax25-tools ax25-apps expect git

git clone https://github.com/EnigmaCurry/bbs.git ~/bbs
```

### Configure your callsign + station ID

```
MY_CALLSIGN=AI7XP-2

echo "${MY_CALLSIGN}" | tee ~/bbs/my_callsign.txt
```

### Configure AX.25 ports

```
read -r MY_CALLSIGN < ~/bbs/my_callsign.txt
echo "radio    ${MY_CALLSIGN}    1200    255    2    BTECH UV-PRO" \
    | sudo tee /etc/ax25/axports
```

### Pair radio bluetooth

```
~/bbs/bt_pair.exp
```

### Bring up radio interface

```
~/bbs/connect_radio.sh
```

### Verify `ax0` device exists

```
$ ip link
...
4: ax0: <BROADCAST,UP,LOWER_UP> mtu 255 qdisc pfifo_fast state UNKNOWN group default qlen 10
    link/ax25 AI7XP-1 brd QST-0 permaddr LINUX-1
```


## Setup server
### Enable ax25d

```
read -r MY_CALLSIGN < ~/bbs/my_callsign.txt

cat <<EOF | sudo tee /etc/ax25/ax25d.conf
[${MY_CALLSIGN}]
default * * * * * * *  ${USER}  ${HOME}/bbs/bbs.py BBS ${MY_CALLSIGN} %S
EOF


cat <<EOF | sudo tee /etc/systemd/system/ax25d.service
[Unit]
Description=AX.25 Daemon
After=network.target

[Service]
Type=forking
ExecStart=/usr/sbin/ax25d -l
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now ax25d &
```

### Create service to bring up the TNC on system boot

```
cat <<EOF | sudo tee /etc/systemd/system/rfcomm-kiss.service
[Unit]
Description=Bind Bluetooth TNC and attach KISS interface
After=bluetooth.target network.target
Requires=bluetooth.target

[Service]
Type=oneshot
RemainAfterExit=true
User=${USER}
WorkingDirectory=${HOME}
Environment=HOME=${HOME}
ExecStart=${HOME}/bbs/connect_radio.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable rfcomm-kiss
```

### Reboot the system to test the startup

After rebooting the pi, you can check the status of the `rfcomm-kiss`
service:

```
sudo systemctl status rfcomm-kiss
```

If the service is operational, the last line of this log should read:

```
The ax0 device still exists after waiting a bit, so it's probably working.
```

This means that the startup script set up the AX.25 connection using
the bluetooth TNC, and it waited a bit, and it checked that it was
still there. This is the only reliably way I have found to detect if
the connection is going to work or not. For more details, see the
Troublshooting section.

## Setup client

 * Install Linux on a second computer.
 * Connect another radio to it.
 * Follow the section for [Common Setup for all AX.25 peers](#common-setup-for-all-ax25-peers).
 * Don't setup ax25d on the client.

### Test calling the BBS

On the server, start `axlisten` so you can see the incoming
transmissions:

```
## On the server, keep this running in its own window for debugging purposes:
sudo axlisten
```

```
## On the client machine, call the station id of your BBS:
axcall -h radio AI7XP-2
```

## Troubleshooting

> The radio's bluetooth was working, but now it's not!

As of firmware 0.8.4-2, the TNC connection is working reliably on the
first connection only. This means that whenever you reboot your Linux
computer, you also need to power cycle the radio. 
