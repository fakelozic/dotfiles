#!/bin/sh
# Prints facts for SystemPanel.qml as tab-separated lines:
#   temp <°C>        CPU package temperature, when a sensor is found
#   uptime <seconds>
#   load <1 min> <5 min> <15 min>
#   proc <%cpu> <%mem> <name>   the five busiest processes right now
for hwmon in /sys/class/hwmon/hwmon*; do
    case $(cat "$hwmon/name") in
        coretemp | k10temp | zenpower)
            printf 'temp\t%s\n' "$(($(cat "$hwmon/temp1_input") / 1000))"
            break
            ;;
    esac
done
printf 'uptime\t%s\n' "$(cut -d' ' -f1 /proc/uptime)"
printf 'load\t%s\n' "$(cut -d' ' -f1-3 /proc/loadavg | tr ' ' '\t')"
# top's first report averages over each process's lifetime; the second covers
# the last half second.
top -b -n 2 -d 0.5 -o %CPU -w 512 |
    awk '/^ *PID/ { report++; next } report == 2 && NF >= 12 && shown < 5 {
        name = $12; for (i = 13; i <= NF; i++) name = name " " $i
        printf "proc\t%s\t%s\t%s\n", $9, $10, name; shown++ }'
