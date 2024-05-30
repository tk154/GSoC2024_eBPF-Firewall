#!/bin/bash


set -e

transfer_files() {
    echo "*** $2 ***"

    scp -O -J $1 \
        ../ipv4_forward/obj/*_${3}_ipv4_forward.o \
        ./scripts/{set_fw.sh,cpu_stats.awk} \
    root@$2:

    echo ""
}

ssh_name=$(cat "settings.json" | jq -cr ".ssh_name")

#transfer_files $ssh_name 10.21.1.2 le
transfer_files $ssh_name 10.22.1.2 be
#transfer_files $ssh_name 10.23.1.2 be
#transfer_files $ssh_name 10.24.1.2 le
