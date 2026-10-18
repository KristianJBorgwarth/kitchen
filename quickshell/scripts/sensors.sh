#!/bin/bash
# sensors.sh — every hwmon temperature, one per line: "chip|label|°C"
for hw in /sys/class/hwmon/hwmon*; do
    name=$(cat "$hw/name" 2>/dev/null) || continue
    for f in "$hw"/temp*_input; do
        [ -e "$f" ] || continue
        v=$(cat "$f" 2>/dev/null) || continue
        label=$(cat "${f%_input}_label" 2>/dev/null)
        echo "$name|$label|$((v / 1000))"
    done
done
