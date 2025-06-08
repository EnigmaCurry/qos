#!/usr/bin/env python3
"""
Very small AX.25 BBS handler for ax25d.

Usage line in /etc/ax25/ax25d.conf:
  [tnc0]
  default * * * * * * *  root  /usr/local/bin/bbs.py  bbs N0CALL %S

argv[1] = local port name (e.g. "tnc0")
argv[2] = remote callsign with SSID (e.g. "AI7XP-5")
"""

import os
import sys
import select
from datetime import datetime
from pathlib import Path

# --------------------------------------------------------------------------- #
# --------------                       I/O helpers                   --------- #
# --------------------------------------------------------------------------- #


def ax25_readline(fd: int = 0, maxlen: int = 512) -> str:
    """
    Read a line from an ax25d‑provided stdin.

    Stops on '.' (talk mode) **or** CR/LF (slave mode).
    Returns the decoded text WITHOUT the terminator.
    """
    buf = bytearray()
    while True:
        select.select([fd], [], [])  # block until data ready
        chunk = os.read(fd, 128)
        for ch in chunk:
            if ch in (0x0D, 0x0A, 0x2E):  # CR, LF, or '.'
                return buf.decode(errors="replace")
            if len(buf) < maxlen:
                buf.append(ch)


def write(text: str) -> None:
    sys.stdout.write(text)
    sys.stdout.flush()


def writeln(text: str = "") -> None:
    sys.stdout.write(f"{text}\r\n")
    sys.stdout.flush()


# --------------------------------------------------------------------------- #
# --------------                Message persistence                  --------- #
# --------------------------------------------------------------------------- #

SPOOL_DIR = Path("/var/spool/ax25bbs")


def ensure_spool() -> None:
    SPOOL_DIR.mkdir(parents=True, exist_ok=True)


def save_message(callsign: str, lines: list[str]) -> Path:
    """
    Save message lines to a timestamped file for the given callsign.
    """
    ensure_spool()
    ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    fname = SPOOL_DIR / f"{callsign}_{ts}.msg"
    with fname.open("w") as f:
        f.write("\n".join(lines))
    return fname


# --------------------------------------------------------------------------- #
# --------------                       Main BBS                      --------- #
# --------------------------------------------------------------------------- #


def run_bbs(ssid: str, remote_call: str) -> None:
    writeln(f"Hi {remote_call}, welcome to the {ssid.upper()} BBS!")
    writeln()
    writeln("Please leave a message (single '.' line ends):")

    lines: list[str] = []
    while True:
        write("> ")
        line = ax25_readline()
        if line == "":
            break
        lines.append(line)

    file_path = save_message(remote_call, lines)

    writeln()
    writeln(f"Message saved to {file_path.name}. 73!")


# --------------------------------------------------------------------------- #
# --------------                        Entrypoint                    -------- #
# --------------------------------------------------------------------------- #


def main() -> None:
    if len(sys.argv) < 3:
        writeln("BBS: missing arguments from ax25d (ssid, remote callsign)")
        sys.exit(1)

    ssid = sys.argv[1]
    remote_call = sys.argv[2]  # %S from ax25d

    try:
        run_bbs(ssid, remote_call)
    except Exception as exc:  # keep ax25d session alive long enough to log
        writeln(f"ERROR: {exc}")
        raise


if __name__ == "__main__":
    main()
