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
import traceback
from datetime import datetime
from pathlib import Path

# --------------------------------------------------------------------------- #
# --------------                       I/O helpers                   --------- #
# --------------------------------------------------------------------------- #


def ax25_readline(fd: int = 0, maxlen: int = 512) -> str:
    """
    Read a line from ax25d‑provided stdin.

    Stops on '.' (talk mode) or CR/LF (slave mode).
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

SPOOL_DIR = Path(__file__).parent / "messages"


def ensure_spool() -> None:
    SPOOL_DIR.mkdir(parents=True, exist_ok=True)


def save_message(sender: str, lines: list[str]) -> Path:
    """
    Save a public message to a timestamped file.
    """
    ensure_spool()
    ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    fname = SPOOL_DIR / f"{ts}.msg"
    with fname.open("w") as f:
        f.write(f"From: {sender}\n")
        f.write("\n".join(lines))
    return fname


def load_all_messages() -> list[tuple[str, list[str]]]:
    """
    Load all public messages from disk.
    """
    ensure_spool()
    msgs = []
    for file in sorted(SPOOL_DIR.glob("*.msg")):
        with file.open() as f:
            lines = f.read().splitlines()
        msgs.append((file.name, lines))
    return msgs


# --------------------------------------------------------------------------- #
# --------------                      BBS Menu                       --------- #
# --------------------------------------------------------------------------- #


def bbs_menu(remote_call: str) -> None:
    while True:
        writeln()
        writeln("Main Menu:")
        writeln("  [R]ead messages")
        writeln("  [S]end a message")
        writeln("  [Q]uit")
        write("> ")
        choice = ax25_readline().strip().lower()

        if choice == "q":
            writeln("Goodbye. 73!")
            return
        elif choice == "s":
            send_message(remote_call)
        elif choice == "r":
            read_messages()
        else:
            writeln("Invalid option.")


def send_message(remote_call: str) -> None:
    writeln()
    writeln("Post a public message (single '.' line ends):")
    lines: list[str] = []
    while True:
        write("> ")
        line = ax25_readline()
        if line == "":
            break
        lines.append(line)

    file_path = save_message(remote_call, lines)
    writeln(f"Message posted as {file_path.name}")


def read_messages() -> None:
    writeln()
    messages = load_all_messages()
    if not messages:
        writeln("No public messages yet.")
        return

    for name, lines in messages:
        writeln(f"\r\n--- {name} ---")
        for line in lines:
            writeln(line)
    writeln("--- End of messages ---")


# --------------------------------------------------------------------------- #
# --------------                    Error Logging                     -------- #
# --------------------------------------------------------------------------- #


def log_error(exc: Exception) -> None:
    log_path = Path(__file__).parent / "errors.log"
    with log_path.open("a") as f:
        f.write(f"[{datetime.utcnow()}] Exception for {sys.argv[2]}:\n")
        traceback.print_exc(file=f)
        f.write("\n")


# --------------------------------------------------------------------------- #
# --------------                        Entrypoint                    -------- #
# --------------------------------------------------------------------------- #


def main() -> None:
    if len(sys.argv) < 3:
        writeln("BBS: missing arguments from ax25d (ssid, remote callsign)")
        sys.exit(1)

    ssid = sys.argv[1]
    remote_call = sys.argv[2]

    try:
        writeln(f"Hi {remote_call}, welcome to the {ssid.upper()} BBS!")
        bbs_menu(remote_call)
    except Exception as exc:
        log_error(exc)
        writeln("An internal error occurred. Logged to errors.log.")


if __name__ == "__main__":
    main()
