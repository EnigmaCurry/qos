# Virtual AX.25 over IP

This will setup a virtual AX.25 network between two VMs connected via IPv4.

## Setup both Debian VMs

 * Create two fresh debian VMs and find their IP addresses.
 
   * For demo purposes, the names of the machines will be named
     `ai7xp-5` and `ai7xp-6`.

 * Do all of these steps on both VMs.

 * SSH into one of the VMs as root.

 * Edit `/etc/hosts`, use your own IP addresses and hostnames:
 
```
# /etc/hosts
192.168.1.5 ai7xp-5 
192.168.1.6 ai7xp-6
```

 * Install dependencies

```
apt update
apt install -y ax25-tools ax25-apps
```

 * Install kernel that supports AX.25
 
   * For native (non-VM) installs, this step is not necessary.
   * For VMs that use the "cloud" kernel, you must switch to the
     standard kernel, and then reboot.
   
```
## Remove "cloud" kernel which does not support AX.25:
apt install linux-image-amd64
apt remove linux-image-cloud-amd64 linux-image-$(uname -r)

reboot
```

## Configure AX.25

 * Do all of these steps on both VMs.
 
 * Set temporary bash variables for the node's configuration:
 
```
## These values should be flipped for the other VM:
MY_CALLSIGN=AI7XP-5
MY_FRIEND=AI7XP-6
```

 * Run the config script:

```
(
set -ex
## Set hostname
hostnamectl set-hostname ${MY_CALLSIGN,,}

## Configure axports
echo "${MY_CALLSIGN}    ${MY_CALLSIGN}    1200    255    2    Virtual TNC" \
    | sudo tee /etc/ax25/axports

## Configure ax25ipd.conf
cat <<EOF | tee /etc/ax25/ax25ipd.conf
socket ip
mode tnc
mycall ${MY_CALLSIGN}
device /dev/ptmx
speed 9600
route ${MY_FRIEND} ${MY_FRIEND,,} b
EOF
)
```

## Start ax25ipd and kissattach

 * Do all of these steps on both VMs.

```
ax25ipd
```

**Take note of the device name to connect to (e.g., `/dev/pts/1`)**

 * Attach TNC

```
## Attach to the device ax25ipd is listening to:
kissattach /dev/pts/1 ${MY_CALLSIGN} ${MY_CALLSIGN}
```

## Test axcall

One one node, run:

```
axlisten ${MY_CALLSIGN}
```

On the other node, initiate a call:

```
axcall ${MY_CALLSIGN} ${MY_FRIEND}
```

(To disconnect, press `Ctrl+]` to bring up the menu.)

You should see the connection via `axlisten` and the client should
eventually connect to a session. The client may send text, but it will
not will receive any response at this point.

## Configure ax25d on one of the nodes

Designate one of the nodes as a BBS server (e.g., `ai7xp-6`).

```
cat <<EOF | sudo tee /etc/ax25/ax25d.conf
[${MY_CALLSIGN}]
default * * * * * * *  root  /usr/local/bin/bbs.py BBS %d %S
EOF
```

```
cat <<'EOF' | tee /usr/local/bin/bbs.py
#!/usr/bin/env python3
"""
Very small AX.25 BBS handler for ax25d.

Usage line in /etc/ax25/ax25d.conf:
  [tnc0]
  default * * * * * * *  root  /usr/local/bin/bbs.py  bbs  %d  %S

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


def run_bbs(port: str, remote_call: str) -> None:
    writeln(f"Hi {remote_call}, welcome to the {port.upper()} BBS!")
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
        writeln("BBS: missing arguments from ax25d (port, remote callsign)")
        sys.exit(1)

    port_name = sys.argv[1]  # cmd‑name or port, depending on ax25d.conf
    remote_call = sys.argv[2]  # %S from ax25d

    try:
        run_bbs(port_name, remote_call)
    except Exception as exc:  # keep ax25d session alive long enough to log
        writeln(f"ERROR: {exc}")
        raise


if __name__ == "__main__":
    main()
EOF
```

```
chmod +x /usr/local/bin/bbs.py
```

Start ax25d:

```
killall ax25d
ax25d -l
```

View logs:

```
journalctl -f
```

On the other node, initiate a call:

```
axcall ${MY_CALLSIGN} ${MY_FRIEND}
```
