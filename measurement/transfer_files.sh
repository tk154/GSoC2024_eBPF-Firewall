#!/bin/bash


set -e

json_get() {
    echo $(echo "$1" | jq -cr "$2")
}

transfer_files() {
    echo "*** $2 ***"

    scp -O -J $1 \
        ../ipv4_forward/obj/{xdp,tc}_${3}_ipv4_forward.o \
        ./openwrt/{set_fw.sh,cpu_stats.awk} \
    root@$2:

    echo ""
}


settings=$(cat "settings.json")
ssh_name=$(json_get "$settings" ".ssh_name")

if [ -z "$ssh_name" ]; then
    echo "settings.json: ssh_name missing"
    exit 1
fi

devices=$(json_get "$settings" ".devices[] | select(.disabled != 1)")

for device in $devices; do
    device_ip=$(json_get "$device" ".ip")
    endianness=$(json_get "$device" ".endianness")

    transfer_files $ssh_name $device_ip $endianness
done
