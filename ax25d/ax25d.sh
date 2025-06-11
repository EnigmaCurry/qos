#!/bin/bash
/usr/sbin/ax25d -l
sleep 1
pgrep ax25d | tail -n1 > /var/run/ax25d.pid
