# Radio Frequency Bulletin Board System

This is a BBS that operates on amateur (ham) radio. No Internet
required!

This is still a work in progress.

## Hardware requirements

This is just what I used specifically, but you may adapt this to
support a wide variety of hardware:

 * Raspberry Pi installed with [Raspberry Pi OS lite
   (arm64)](https://www.raspberrypi.com/software/).
 * Baofeng type HT radio (for 2M FM).
 * [Digirig Mobile](https://digirig.net/product/digirig-mobile/) and
   [K-1 style cable](https://digirig.net/product/baofeng-cables/) to
   connect to the radio.
 * A duplicate set of equipment (Pi, radio, digirig) to use as a test
   client.

## Software overview

This setup will use the following software on Raspberry Pi OS:

 * [direwolf](https://github.com/wb2osz/direwolf) - a software
   "soundcard" (TNC) for AX.25/KISS packet radio.
   * This will connect the audio in/out of the radio via the digirig
     sound card. It will also interface the PTT of the radio via
     serial RTS, automatically controlling when the radio transmits.
     The digirig is connected to the Raspberry Pi via a single USB
     cable.
   * direwolf speaks the KISS protocol and creates a pseudo-terminal
     (ptty) `/tmp/kisstnc` that the Kernel AX.25 stack may interface
     with.
 * [ax25-tools](https://packages.debian.org/bookworm/ax25-tools) - a
   collection of interface tools for the Linux Kernel AX.25 networking
   stack.
    * `kissattach` will connect the direwolf ptty (`/tmp/kisstnc`) and
      attach that to a Kernel AX.25 network device (`ax0`).
    * `ax25d` is used to create a daemon listener service to run our
      BBS program.
    * `axconnect` is used from the remote client to connect to the
      BBS.

## Setup Raspberry Pi

Follow the [Raspberry Pi Getting Started
guide](https://www.raspberrypi.com/documentation/computers/getting-started.html)
to install and configure the OS.

Install extra dependencies:

```
sudo apt update
sudo apt install -y ax25-apps ax25-tools direwolf
```

## Identify the sound device

Plug in your digirig via USB port. Identify the name of the device:

```
cat /proc/asound/cards
```

This will output something like:

```
 0 [ALC1220         ]: HDA-Intel - HDA ALC1220
                      ...
 2 [Device          ]: USB-Audio - USB PnP Sound Device
                      USB PnP Sound Device at ...
```

The digirig device identifies literally as `Device` (yes, its a pretty
generic name, but luckily it is still unique on my system.)

The ALSA name for this device is literally `plughw:Device,0`, which is
the name you will need to tell direwolf to use.

## Create direwolf.conf

Create the direwolf config file:

```
cat <<EOF | sudo tee /etc/direwolf.conf
### Define sound device:
# Set the primary audio device id (name,device) as reported by `cat /proc/asound/cards`
ADEVICE  plughw:Device,0

### Define channels:
CHANNEL 0
# Set your own callsign and station identifer:
MYCALL AI7XP-1
# Set modem baud
MODEM 1200
# Set PTT for digirig:
PTT /dev/ttyUSB0 RTS
EOF
```

You need to adjust the following items:

 * `CHANNEL` set your channel id `0`. You only need one channel right
   now. The config that follows is being defiend for channel `0`.
 * `MYCALL` set your callsign and station unique identifier (SSID) for
   channel `0`. (For example, if `AI7XP` is your callsign, add `-1`
   for the first station, `-2` for the second station, etc.)
 * `MODEM` sets the baud rate of channel `0`. Use 1200 unless you know
   what you're doing.
 * `PTT` set the device `/dev/ttyUSB0` of the digirig and set the
   control mode `RTS` (for channel `0`). This will allow direwolf to
   control the radio transmitter.

## Enable the direwolf service

By default, direwolf does not create a pseudo-terminal (ptty). We need
a ptty to use with `kissattach`, so we need to create a systemd
override to modify the direwolf command the service runs:

```
sudo mkdir -p /etc/systemd/system/direwolf.service.d
cat <<EOF | sudo tee /etc/systemd/system/direwolf.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/bin/direwolf -p -t 0 -c /etc/direwolf.conf
EOF
```

Enable the direwolf service:

```
sudo systemctl daemon-reload
sudo systemctl enable --now direwolf
```

Check the direwolf log to ensure it started up correctly:

```
sudo journalctl --unit direwolf
```

```
May 30 19:21:39 tnc systemd[1]: Started direwolf.service - DireWolf is a software "soundcard" modem/TNC and APRS decoder.
May 30 19:21:39 tnc direwolf[589]: Dire Wolf version 1.6
May 30 19:21:39 tnc direwolf[589]: Includes optional support for:  gpsd hamlib cm108-ptt
May 30 19:21:39 tnc direwolf[589]: Reading config file /etc/direwolf.conf
May 30 19:21:39 tnc direwolf[589]: Audio device for both receive and transmit: plughw:Device,0  (channel 0)
May 30 19:21:39 tnc direwolf[589]: Channel 0: 1200 baud, AFSK 1200 & 2200 Hz, E+, 44100 sample rate.
May 30 19:21:39 tnc direwolf[589]: Ready to accept AGW client application 0 on port 8000 ...
May 30 19:21:39 tnc direwolf[589]: Ready to accept KISS TCP client application 0 on port 8001 ...
May 30 19:21:39 tnc direwolf[589]: Virtual KISS TNC is available on /dev/pts/0
May 30 19:21:39 tnc direwolf[589]: Created symlink /tmp/kisstnc -> /dev/pts/0
```

 * It should list the correct sound device (`plughw:Device,0`).
 * It should list the correct Virtual KISS TNC symlink `/tmp/kisstnc`.
   (If it does not, the systemd override to set the `-p -t 0` args
   didn't work).

## Setup AX.25 Port

You need to configure the AX.25 with your callsign and TNC:

```
echo "radio    AI7XP-1    1200    255    2    Direwolf TNC" \
    | sudo tee /etc/ax25/axports
```

 * `radio` is the alias of the TNC you are creating.
 * `AI7XP-1` is the example callsign and station identifier. Use your
   own!
 * `1200` sets the baud rate.
 * `255` sets the maximum packet length size.
 * `2` sets the default window size.
 * `Direwolf TNC` is a freeform description of the TNC.

## Enable the kissattach service

Raspberry Pi OS does not provide a default service definition for
kissattach, so we must create one.

Create the startup script:

```
cat <<'EOF' | sudo tee /usr/local/bin/kissattach-auto.sh
#!/bin/bash
set -euox pipefail

AX_PORT="radio"
TRIES=20
SLEEP_INTERVAL=1

for i in $(seq "$TRIES"); do
    DEVICE=$(journalctl -u direwolf --no-pager -n 50 \
             | grep -o '/dev/pts/[0-9]*' | tail -n1)
    if [[ -n $DEVICE && -e $DEVICE ]]; then
        echo "[kissattach] Found PTY: $DEVICE"

        #--- Attach KISS device --------------------------------------------
        /usr/sbin/kissattach "$DEVICE" "$AX_PORT"

        #--- Tune KISS parameters ------------------------------------------
        /usr/sbin/kissparms -p "$AX_PORT" \
                            -t 150   \
                            -s 10    \
                            -r 191
        exit 0
    fi
    echo "[kissattach] Waiting for Direwolf PTY... ($i/$TRIES)"
    sleep "$SLEEP_INTERVAL"
done

echo "[kissattach] Failed to find Direwolf PTY after $TRIES tries." >&2
exit 1
EOF
```

Set the script executable:

```
sudo chmod +x /usr/local/bin/kissattach-auto.sh
```

Create the systemd service file:

```
cat <<EOF | sudo tee /etc/systemd/system/kissattach.service
[Unit]
Description=Attach KISS to Direwolf PTY from systemd journal
After=direwolf.service
Requires=direwolf.service

[Service]
Type=simple
ExecStart=/usr/local/bin/kissattach-auto.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
```

Enable the service:

```
sudo systemctl enable --now kissattach.service
```

Verify the `ax0` network device now exists:

```
ip link show dev ax0
```

which should show something like (notice the callsign and SSID is
shown according to `/etc/ax25/axports`):

```
4: ax0: <BROADCAST,UP,LOWER_UP> mtu 255 qdisc pfifo_fast state UNKNOWN mode DEFAULT group default qlen 10
    link/ax25 AI7XP-1 brd QST-0 permaddr LINUX-1
```

## Configure the radio

 * Plug the twin prong K1 connector into the HT radio. Plug the other
   end into the digirig.
 * Set the radio frequency you wish to use and set the squelch to 0.
 * The radio should now be receiving audio (static), although you will
   not hear it out of the radio speaker when the cable is plugged in.
   A green light should illuminate indicating its receiving.

## Setup the client

Setup a second Raspberry Pi or other computer to use as a client.
Configure it the same way as the first one:

 * Configure direwolf
 * Configure /etc/ax25/axports
 * Configure kissattach

## Monitor connections

On the BBS server, you can monitor connections:

```
axlisten
```

And check the logs:

```
tail -f /home/bbs/bbs.log
```

## Make a test call

To connect the client to the BBS, run the `axcall` command, specifying
the TNC and the callsign+SSID of the BBS:

```
axcall radio AI7XP-1
```

This should call the BBS server. Although no actual BBS script is
installed yet, and you won't get any response on the client yet, this
should test that the client radio transmit light turn red briefly, and
you should see the connection attempt via `axlisten` on the server:

```
# axlisten
radio: fm AI7XP-2 to AI7XP-1 ctl SABM+ 21:34:59.246235 
```

## Setup ax25d and the BBS script

ax25d is the daemon process that will listen for incoming connections
and start and attach our BBS script.

 * You only need to configure ax25d on the BBS server, not the client!

Create a `bbs` user to run the BBS:

```
sudo useradd -r -s /bin/bash -d /home/bbs bbs
sudo mkdir -p /home/bbs
sudo chown bbs:bbs /home/bbs
```

Create `/etc/ax25/ax25d.conf` (it probably already exists, but you
will be overwriting it):

```
cat <<EOF | sudo tee /etc/ax25/ax25d.conf
[AI7XP-1]
default  * * * * * *  - bbs  /usr/local/bin/bbs bbs
EOF
```

 * `default` means it will allow *any* callsign to connect to your
   BBS. You can create different scripts for different callers and
   list them here, but for now we'll just have one.
 * Configure your own callsign+SSID (enclosed in square brackets on
   the first line)
 * The program that will be run when clients connect is
   `/usr/local/bin/bbs`.
   
Create a basic BBS script for initial testing purposes:

```
cat <<'FOF' | sudo tee /usr/local/bin/bbs
#!/bin/bash
# Simple AX.25 BBS script invoked by ax25d

: "${AX25_CALL:=localhost}"
: "${AX25_USER:=UNKNOWN}"
: "${AX25_PORT:=local}"

echo
echo "Welcome to the BBS on $AX25_CALL!"
echo "You are connected via port: $AX25_PORT"
echo "Remote callsign: $AX25_USER"
echo "Type 'help' to see available commands."

LOGFILE="/home/bbs/bbs.log"
mkdir -p "$(dirname "$LOGFILE")"
printf '%s - %s connected to %s on %s\n' \
       "$(date)" "$AX25_USER" "$AX25_CALL" "$AX25_PORT" >>"$LOGFILE"

while true; do
    printf '> \r\n'                # prompt with newline so it flushes.

    # Read until CR (0x0D).  If the peer ever sends \n, we handle that too.
    if ! IFS= read -r -d $'\r' cmd ; then
        break                   # disconnect / EOF
    fi
    cmd=${cmd//$'\n'/}          # strip stray LF if CR‑LF arrives
    cmd=${cmd//$'\r'/}          # strip CR just in case

    case "$cmd" in
        help)
            cat <<'EOF'
Available commands:
  help   - Show this help message
  list   - List messages
  read   - Read a message
  exit   - Disconnect
EOF
            ;;
        list)
            cat <<'EOF'
Messages:
  1. Hello from the sysop
  2. Node test message
EOF
            ;;
        read)
            cat <<EOF
Reading message 1:
--------------------
Hi $AX25_USER, welcome to the BBS!
Thanks for connecting to $AX25_CALL.
73 de AI7XP
--------------------
EOF
            ;;
        exit)
            echo "Goodbye $AX25_USER!"
            break
            ;;
        *)
            echo "Unknown command.  Type 'help' for available commands."
            ;;
    esac
done
FOF
u```

Make the script executable:

```
sudo chmod a+x /usr/local/bin/bbs
```

Enable the ax25d service:

```
cat <<EOF | sudo tee /etc/systemd/system/ax25d.service
[Unit]
Description=AX.25 daemon
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/ax25d -l

[Install]
WantedBy=multi-user.target
EOF
```

```
sudo systemctl enable --now ax25d &
```

Check that is starts up:

```
journalctl --unit ax25d | tail
```

```
May 30 22:42:58 tnc systemd[1]: Starting ax25d.service - AX.25 daemon...
May 30 22:42:58 tnc ax25d[1762]: starting
May 30 22:42:58 tnc ax25d[1762]: new config file loaded successfully
```

## Call the BBS

Now that ax25d is listening and the BBS script is installed, you can
connect to it from the client:


```
# On the client:
axcall radio AI7XP-1 
```
