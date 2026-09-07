#!/bin/bash
# hwmon_temp.sh <hwmon-name> [temp-label]
# With a label: prints that labeled sensor's temp in °C.
# Without one: scans every hwmon device with that name and prints the highest reading
# (for devices like spd5118 RAM DIMM sensors, which have no label and one per DIMM).
name="$1"
label="$2"

if [ -n "$label" ]; then
    for hw in /sys/class/hwmon/hwmon*; do
        [ "$(cat "$hw/name" 2>/dev/null)" = "$name" ] || continue
        for f in "$hw"/temp*_label; do
            [ -e "$f" ] || continue
            [ "$(cat "$f")" = "$label" ] || continue
            input="${f%_label}_input"
            awk '{print int($1 / 1000)}' "$input"
            exit 0
        done
    done
    echo 0
    exit 0
fi

max=0
for hw in /sys/class/hwmon/hwmon*; do
    [ "$(cat "$hw/name" 2>/dev/null)" = "$name" ] || continue
    for f in "$hw"/temp*_input; do
        [ -e "$f" ] || continue
        v=$(awk '{print int($1 / 1000)}' "$f")
        [ "$v" -gt "$max" ] && max=$v
    done
done
echo "$max"
