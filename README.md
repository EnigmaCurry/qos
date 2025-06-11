# QOS - a container OS for digital ham radio operators

QOS is a system to run various amateur radio applications inside of
Podman containers. It includes a comprehensive menu driven
configuration and management tool. Make your next QSO with QOS.

## Dependencies

A Linux computer that runs systemd:

 * Only the following distributions are supported:
   * Debian or debian-like (including Raspberry Pi OS)
   * Fedora (including all spins, including atomic/rpm-ostree)
   * (Support could be added for any distribution that can run systemd
     and has a package for podman.)

Support for the following radios is available:

 * BTECH UV-PRO, Vero VR‑N76, Radioddity GA-5WB, and other clones.
   (These are all essentially the same radio) - these radios
   communicate with Linux via bluetooth (KISS TNC).
 * More radios TODO.

## Get started

### Setup radio

Follow the directions to setup your radio, then come back here.

 * [BTECH UV-PRO, Vero VR-N76, Radioddity GA-5WB](#btech-uv-pro-vero-vr-n76-radioddity-ga-5wb)

### Setup Linux

 * Log in to the Linux system as `root`.
 * Install the `git` package.
   * Debian:
     * `sudo apt install git`
   * Fedora: 
     * for dnf based systems: `sudo dnf install git`
     * for rpm-ostree based systems: `sudo rpm-ostree install git` (and then reboot).
     
 * Download the QOS git repository:
 
```
git clone https://github.com/EnigmaCurry/QOS.git ~/qos
cd ~/qos
```

 * Run `qos` to access the main menu, allowing you to configure and manage the system.
 
## Setup AX.25

 * From the `QOS` main menu, choose `ax25`, and go through the
   following sections:
   * Choose `settings` and configure your station callsign.
   * Put your radio into pairing mode, and then choose `pair`.
   * Once paired, choose `enable (rfcomm KISS service)`.
   * Choose `check (AX.25 connection)` and verify the service started.
 
If successful, the status should show the service is `active
(exited)`, and you should see the details for a network device named
`ax0`, which does not show an IP address, but instead shows your
station callsign, e.g.:

```
● rfcomm-kiss.service - Bind Bluetooth TNC and attach KISS interface
     Loaded: loaded (/etc/systemd/system/rfcomm-kiss.service; enabled; preset: enabled)
     Active: active (exited) since Tue 2025-06-10 22:39:37 MDT; 21min ago
...
4: ax0: <BROADCAST,UP,LOWER_UP> mtu 255 qdisc pfifo_fast state UNKNOWN mode DEFAULT group default qlen 10
    link/ax25 AI7XP-2 brd QST-0 permaddr LINUX-1
```

## Setup Radio

Here are instructions for specific radios

### BTECH UV-PRO, Vero VR-N76, Radioddity GA-5WB

The BTECH UV-PRO (and similar radios) need to be updated to run the
latest firmware. To do this follow these steps:

 * Use an Android smartphone and download the BTECH app from the play
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

#### Troubleshooting

> The radio's bluetooth was working, but now it's not!

As of firmware 0.8.4-2, the TNC connection is working reliably on the
first connection only. This means that whenever you reboot your Linux
computer, you also need to power cycle the radio. 

## Credits

This software repository includes many scripts and things taken from
elsewhere. Here is a catalog of them all:

 * Bluetooth pairing script ([bt_pair.exp](_script/bt_pair.exp)) for
   the BTECH UV-PRO, taken from
   [TheCommsChannel/TC2-APRS-BBS](https://github.com/TheCommsChannel/TC2-APRS-BBS)
   (GPLv3).
