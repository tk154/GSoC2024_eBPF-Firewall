#!/bin/bash

set -e


json_get() {
    echo $(echo "$1" | jq -cr "$2")
}

json_to_string() {
	echo $(echo "$1" | jq -r 'to_entries | map("\(.key) \(.value)") | join(" ")')
}

cleanup() {
    echo -e "\n\nCleanup!"
    rm -rf "$data_folder"

    device_ips=$(json_get "$devices" ".ip")

    ssh -T "$ssh_name" <<- EOF
        killall -qw tcpdump iperf3
        rm -f "$trace_file" "$tcpstat_file" "$cpu_load_file"

		for device_ip in $device_ips; do
            echo "Resetting firewall on \$device_ip"
            ssh -n root@\$device_ip \
                "./$set_fw_script; killall -q $cpu_stats_script; rm -f '$cpu_load_file'"
		done
	EOF

	exit 1
}

trap cleanup ERR


trace_file=trace.pcap
tcpstat_file=trace.pcap.csv
cpu_load_file=cpu_load.csv

settings_file=settings.json
set_fw_script=set_fw.sh
cpu_stats_script=cpu_stats.awk


data_folder=data/
[ -n "$1" ] && data_folder+="$1-"
data_folder+=$(date "+%F@%H-%M-%S")

settings=$(cat "$settings_file")
ssh_name=$(json_get "$settings" ".ssh_name")

devices=$(json_get "$settings" ".devices[] | select(.disabled != 1)")
parts=$(json_get "$settings" ".parts[] | select(.disabled != 1) | .name")
seconds_per_part=$(json_get "$settings" ".seconds_per_part")
seconds_before_parts=$(json_get "$settings" ".seconds_before_parts")

options=$(json_get "$settings" ".options[] | select(.disabled != 1)")
port=$(json_get "$settings" ".port")


for device in $devices; do
    device_name=$(json_get "$device" ".name")
    device_ip=$(json_get "$device" ".ip")

    source_netns=$(json_get "$device" ".source_netns.name")
    sink_netns=$(json_get "$device" ".sink_netns.name")
    sink_ip=$(json_get "$device" ".sink_netns.ip")

    echo "***** Starting tests on $device_name *****"

    for option in $options; do
        option_name=$(json_get "$option" ".name")
        client_options=$(json_get "$option" ".client")
		client_options=$(json_to_string "$client_options")
        server_options=$(json_get "$option" ".server")
        server_options=$(json_to_string "$server_options")

        echo "*** Trying option $option_name ***"

        ssh -T "$ssh_name" <<- EOF
            set -e
			trap 'killall -q iperf3 tcpdump' ERR

            ip netns exec "$sink_netns" \
                iperf3 -p "$port" -s $server_options > /dev/null &

            ip netns exec "$sink_netns" \
				tcpdump dst port "$port" -w "$trace_file" -s 256 -n &

            ssh -n root@$device_ip \
				"./$cpu_stats_script > '$cpu_load_file' &"

            for part in $parts; do
                ssh -n root@$device_ip "./$set_fw_script \$part" &
                sleep "$seconds_before_parts"

                echo -e "\nStarting part \$part"
                ip netns exec "$source_netns" \
                    iperf3 -c "$sink_ip" \
                           -t "$seconds_per_part" $client_options \
                > /dev/null

                echo "Part \$part finished"
            done

            echo ""

			ssh -n root@$device_ip "killall $cpu_stats_script"
			killall -w tcpdump iperf3

            tcpstat 1 -r "$trace_file" -o '%S,%b\n' > "$tcpstat_file"
			scp -O root@$device_ip:"$cpu_load_file" .
		EOF

        echo -e "\n*** Option $option_name finished ***"

        folder=$data_folder/$device_name
		mkdir -p "$folder"

        scp "$ssh_name":"$tcpstat_file"  "$folder/${option_name}_${tcpstat_file}"
        scp "$ssh_name":"$cpu_load_file" "$folder/${option_name}_${cpu_load_file}"

        echo ""
    done

    echo -e "***** Tests finished on $device_name *****\n\n"

    ssh -T "$ssh_name" <<- EOF
        ssh -n root@$device_ip "./$set_fw_script; rm '$cpu_load_file'"
	EOF
done

ssh -T "$ssh_name" << EOF
    rm "$trace_file" "$tcpstat_file" "$cpu_load_file"
EOF

echo "$settings" > "$data_folder/$settings_file"
