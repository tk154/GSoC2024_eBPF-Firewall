# GSoC 2024 – eBPF-Firewall

This repository contains all the work done during <b>Google Summer of Code 2024</b> regarding the <a href="https://freifunk.net/en/">Freifunk</a> topic: <a href="https://summerofcode.withgoogle.com/programs/2024/projects/u79z1qYm">eBPF performance optimisations for a new OpenWrt Firewall</a>.
The project aims to introduce a new firewall software offloading variant to OpenWrt by intercepting an incoming data packet from the NIC as early as possible inside or even before the network stack through the eBPF XDP or TC hook. And after that, apply possible NAT (Network Address Translation) and drop or redirect the intercepted package to another network interface.
You can find more info about the project on my <a href="https://blog.freifunk.net/?s=GSoC+2024%3A+eBPF+performance+optimizations+for+a+new+OpenWrt+Firewall">Freifunk blogs</a>.

You can find an explanation for the codes and scripts in their respective directories.
The implementation can be found inside this GitHub repository: https://github.com/tk154/eBPF-Firewall
