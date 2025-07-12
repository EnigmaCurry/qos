#!/usr/bin/env python3
import aprs
import sys
import os
from pprint import pprint

DEVICE = os.getenv("DEVICE", "/dev/rfcomm0")
BAUDRATE = int(os.getenv("BAUDRATE", "9600"))


def main():
    aprs_serial = aprs.SerialKISS(DEVICE, BAUDRATE)
    aprs_serial.start()

    print(f"Listening for APRS UI frames on {DEVICE} at {BAUDRATE} baud...\n")
    try:
        while True:
            packets = aprs_serial.read()
            for packet in packets:
                print_packet(packet)
    except KeyboardInterrupt:
        print("\nExiting...")
    finally:
        aprs_serial.stop()


def print_packet(packet):
    try:
        print(f"{packet.source} > {packet.destination}", end="")
        if packet.path:
            print(f" via {','.join(packet.path)}")
        else:
            print()
        ptype = getattr(packet, "type", "unknown")
        info = getattr(packet, "info", None)
        if info:
            text = str(getattr(info, "text", "<no text>"))
            addressee = str(getattr(info, "addressee", "<no destination>"))
            print(f"  [{ptype}] [to:{addressee}] {text}\n")
    except Exception as e:
        print(f"[!] Failed to decode packet: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
