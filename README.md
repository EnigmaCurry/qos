# QOS - a container OS for digital ham radio operators

QOS is a system to run various amateur radio applications inside of
Podman containers on top of Raspberry Pi OS and/or Fedora IoT. It
includes a comprehensive menu driven configuration and management
tool. Make your next QSO with QOS.

## Troubleshooting

> The radio's bluetooth was working, but now it's not!

As of firmware 0.8.4-2, the TNC connection is working reliably on the
first connection only. This means that whenever you reboot your Linux
computer, you also need to power cycle the radio. 

## Credits
This software repository includes many script and things taken from
elsewhere. Here is a catalog of them all:

 * Bluetooth pairing script ([bt_pair.exp](_script/bt_pair.exp)) for
   the BTECH UV-PRO, taken from
   [TheCommsChannel/TC2-APRS-BBS](https://github.com/TheCommsChannel/TC2-APRS-BBS)
   (GPLv3).
