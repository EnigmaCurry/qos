#!/usr/bin/env python3
import aprs
import sys
import os

DEVICE = os.getenv("DEVICE", "/dev/rfcomm0")
BAUDRATE = int(os.getenv("BAUDRATE", "9600"))


def main():
    aprs_serial = aprs.SerialKISS(DEVICE, BAUDRATE)
    aprs_serial.start()

    print(f"Listening for APRS UI frames on {DEVICE} at {BAUDRATE} baud...\n")
    try:
        while True:
            packet = aprs_serial.read()
            if not packet:
                continue
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
        print(f"  [{packet.type}] {packet.text}\n")
    except Exception as e:
        print(f"[!] Failed to decode packet: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
