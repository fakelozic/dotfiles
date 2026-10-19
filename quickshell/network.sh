#!/bin/sh
# Prints the interface carrying the default route for Network.qml, as
# tab-separated kind, signal, essid, ifname and ipaddr; or "disconnected".
dev=$(ip route show default | awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
if [ -z "$dev" ]; then
    echo disconnected
    exit
fi
ip=$(ip -4 -o addr show dev "$dev" | awk '{ sub("/.*", "", $4); print $4; exit }')

if [ -d "/sys/class/net/$dev/wireless" ]; then
    line=$(nmcli -t -f ACTIVE,SIGNAL,SSID device wifi list ifname "$dev" --rescan no | grep -m1 '^yes:')
    rest=${line#yes:}
    signal=${rest%%:*}
    # nmcli escapes colons in the SSID.
    essid=$(printf '%s' "${rest#*:}" | sed 's/\\:/:/g')
    printf 'wifi\t%s\t%s\t%s\t%s\n' "$signal" "$essid" "$dev" "$ip"
else
    printf 'ethernet\t\t\t%s\t%s\n' "$dev" "$ip"
fi
