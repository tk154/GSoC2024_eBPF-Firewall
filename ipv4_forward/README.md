# ipv4_forward

This folder contains a small <a href="https://github.com/tk154/GSoC2024_eBPF-Firewall/blob/main/ipv4_forward/ipv4_forward.c">eBPF program</a> that forwards all IPv4 network packages received by the network device where the program is attached. To build the eBPF objects, you can use the Makefile:
```
make
```
<br>

That will create four eBPF object files under ```obj/``` for little and big endian machines and the XDP and TC hook. You can also specify the following Makefile targets for specific builds: ```xdp```, ```tc```, ```le```, ```be```, ```xdp-le```, ```tc-le```, ```xdp-be```, or ```tc-be```.

After you have built the eBPF object, you can transfer it to your target machine/router (e.g., per ```scp```, ```croc```, ...). To attach the program to the XDP hook, you can use the ```ip``` command. The following commands use the network interface ```eth0``` as an example:
```
ip link set eth0 xdp obj xdp_*e_ipv4_forward.o sec ipv4_forward
```
<br>

To detach it, run:
```
ip link set eth0 xdp off
```
<br>

To attach the program to the TC hook, you can use the ```tc``` command:
```
tc qdisc add dev eth0 clsact
tc filter add dev eth0 ingress bpf da obj tc_*e_ipv4_forward.o sec ipv4_forward
```
<br>

To detach it, run:
```
tc qdisc del dev eth0 clsact
```
<br>

For support in OpenWrt, you need the following packages/symbols selected inside OpenWrt's build configuration:
```
CONFIG_PACKAGE_kmod-sched-core=y
CONFIG_PACKAGE_kmod-sched-bpf=y

CONFIG_PACKAGE_ip-full=y
CONFIG_PACKAGE_tc-bpf=y

# optionally, for bpf_printk (debugging) support
CONFIG_KERNEL_KPROBES=y
```
