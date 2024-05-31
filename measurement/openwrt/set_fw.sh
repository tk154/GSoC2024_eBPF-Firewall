#!/bin/ash

links="lan1 lan2"

bpf_object="*e_ipv4_forward.o"
bpf_section="ipv4_forward"


set_xdp_generic_packet_headroom() {
    for link in $links; do
        echo $1 > "/sys/class/net/$link/xdp_generic_packet_headroom"
    done
}

set_generic_receive_offload() {
    for link in $links; do
        ethtool -K $link generic-receive-offload $1
    done
}

set_xdp() {
    case $1 in
        "load")
            for link in $links; do
                ip link set $link xdp obj xdp_$bpf_object sec $bpf_section
            done
        ;;

        *)
            for link in $links; do
                ip link set $link xdp off
            done
        ;;
    esac
}

set_tc() {
    case $1 in
        "load")
            for link in $links; do
                tc qdisc add dev $link clsact
                [ $? -eq 0 ] && \
                    tc filter add dev $link ingress bpf da obj tc_$bpf_object sec $bpf_section
            done
        ;;

        *)
            for link in $links; do
                tc qdisc del dev $link clsact 2>/dev/null
            done
        ;;
    esac
}

set_flow_offloading() {
    case $1 in
        "sw")
            uci set firewall.@defaults[0].flow_offloading='1'
            uci set firewall.@defaults[0].flow_offloading_hw='0'
        ;;

        "hw")
            uci set firewall.@defaults[0].flow_offloading='1'
            uci set firewall.@defaults[0].flow_offloading_hw='1'
        ;;

        *)
            uci set firewall.@defaults[0].flow_offloading='0'
            uci set firewall.@defaults[0].flow_offloading_hw='0'
        ;;
    esac
}

fw4() {
    if [ $1 == "status" ]; then
        echo $(service firewall $1)
    else
        service firewall $1
    fi
}

set_fw() {
    set_generic_receive_offload on
    set_flow_offloading off
    set_xdp unload
    set_tc unload

    case $1 in
        "off")
            [[ "$(fw4 status)" == "active"* ]] && fw4 stop
            return 0
        ;;

        "sw_flow")
            set_generic_receive_offload off
            set_flow_offloading sw
        ;;

        "hw_flow")
            set_generic_receive_offload off
            set_flow_offloading hw
        ;;

        "xdp"*)
            if [ $1 != "xdp" ]; then
                headroom="${1//[^0-9]/}"
                set_xdp_generic_packet_headroom $headroom
            fi

            set_xdp load
        ;;

        "tc")
            set_generic_receive_offload off
            set_tc load
        ;;
    esac

    uci commit firewall
    [[ "$(fw4 status)" == "active"* ]] && fw4 restart || fw4 start
}

set_fw $1
