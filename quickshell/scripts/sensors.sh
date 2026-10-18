#!/bin/bash
# sensors.sh — every hwmon temperature, one per line: "chip|label|°C"
# builtins only (read, not $(cat)): this runs on a timer and each fork is costly under EDR/AV
for hw in /sys/class/hwmon/hwmon*; do
    read -r name 2>/dev/null <"$hw/name" || continue
    for f in "$hw"/temp*_input; do
        [ -e "$f" ] || continue
        read -r v 2>/dev/null <"$f" || continue
        label=""
        read -r label 2>/dev/null <"${f%_input}_label"
        echo "$name|$label|$((v / 1000))"
    done
done
