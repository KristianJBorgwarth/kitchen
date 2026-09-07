#!/bin/bash
# app_mem.sh <process-name> — resident memory used by the process, in MiB
pid=$(pgrep -x "$1" | head -n1)
[ -z "$pid" ] && echo 0 && exit 0
awk '/VmRSS/ {print int($2 / 1024)}' /proc/"$pid"/status
