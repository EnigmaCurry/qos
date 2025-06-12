# QOS - a container OS for digital amateur radio operators

QOS is a system to run various amateur radio applications inside of
Podman containers. It includes a comprehensive menu driven
configuration and management tool. Make your next QSO with QOS.

ALPHA!

## Dependencies

A Linux computer that runs systemd:

 * Only the following distributions are supported:
   * Debian or debian-like (including Raspberry Pi OS)
   * Fedora (including all spins, including atomic/rpm-ostree)
   * (Support could be added for any distribution that can run systemd
     and has a package for podman.)

Support for the following radios is available:

 * BTECH UV-PRO, Vero VR‑N76, Radioddity GA-5WB (these are all
   essentially the same radio) - these radios feature a bluetooth
   (serial) KISS TNC, which is directly supported by the Linux kernel
   AX.25 stack (direwolf is not required).
 * More radios TODO.

## Get started

### Setup radio

Follow the directions to setup your specific radio, then come back
here to setup Linux.

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
git clone https://github.com/EnigmaCurry/qos.git ~/qos
cd ~/qos
```

 * (Optional) Add `~/qos` to your `PATH` environment var and setup Bash completion.
 
```
## In ~/.bashrc
export PATH="${PATH}:${HOME}/qos"
source <(qos bash_completion)
```

 * To access the main menu, run `~/qos/qos` (or `qos`, if you modified
   the `PATH`).

## Command Line and Menu driven interface

The `qos` command has two different modes:

 * As a comprehensive menu driven interface to explore all subcommands.
 * As a pure command line tool with explicit arguments.
 
If run without any arguments, `qos` will show you the main menu:

```
? qos
> config
  apps
[↑↓ to move, enter to select, type to filter, ESC to cancel]
```

Use the arrow keys to navigate, and press Enter to select an item. 

To configure the global settings, navigate to the `config` menu, and
then `settings`. Type your Callsign when requested, and do so for any
other settings it asks for. The values you enter will be saved in the
`.env` file.

You can also invoke any sub-menu or sub-command directly from the
command line:

```
qos config settings
```

This is two ways of doing the same thing. Throughout this document,
the explicit CLI interface will be used in order to be unambiguous,
but you should know as well that you can run any command by menu
diving through the main `qos` entrypoint.

## Pair radio and enable the rfcomm-kiss service

Put your radio into pairing mode, and then invoke the pairing script:

```
qos config radios pair
```

If this does not work the first time, remove any existing pairings in
the radio, power cycle the radio, and try again.

Enable the `rfcom-kiss` service to setup the serial KISS TNC device:

```
qos config radios rfcomm enable
```

Follow the directions it gives you:

 * Power cycle the radio.
 * Reboot.
 * Check the rfcomm-kiss service is started and healthy
 
```
# After reboot:
qos config radios rfcomm status
```

You should check that the service ran successfully:

```
● rfcomm-kiss.service - Bind Bluetooth KISS TNC
     Loaded: loaded (/etc/systemd/system/rfcomm-kiss.service; enabled; preset: enabled)
     Active: active (exited) since Wed 2025-06-11 17:16:43 MDT; 23s ago
....
Jun 11 17:16:43 linux connect_radio.sh[584]: + rfcomm bind /dev/rfcomm0 38:XX:XX:XX:XX:XX 1
Jun 11 17:16:43 linux systemd[1]: Finished rfcomm-kiss.service - Bind Bluetooth KISS TNC.
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
       * Find the smartphone you paired earlier, and `UNPAIR` it, so
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
       * Choose the low power setting for testing, and increase it
         depending on your need.
     * `Tail Elimination` (toggle OFF)
     * `Digital Mute`
       * Optional, on or off, depending if you like to hear the
       *outgoing* modem sounds.
 
 * Tune the radio to the desired frequency.
 
   * Consult your local band plan.
   * [ARRL](https://www.arrl.org/band-plan)
     * [Packet Radio Frequency Recommendations of the Committee on
       Amatuer Radio Digital
       Communication](https://www.arrl.org/files/file/8803051.pdf)
   * [UTVHF society](https://utahvhfs.org/bandplan1.html)
   * Suggestions:
     * `145.01`, `145.03`, `145.05`, `145.07`, `145.09`
   
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
