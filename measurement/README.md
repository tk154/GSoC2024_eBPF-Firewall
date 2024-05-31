# Measurement

This folder contains a measurement and plotting script to test the throughput performance of the <a href="https://github.com/tk154/GSoC2024_eBPF-Firewall/blob/main/ipv4_forward/ipv4_forward.c">ipv4_forward eBPF program</a> on an OpenWrt device using ```iperf3```. You can find the idea of the measurement setup in the following picture. The network switch is optional but is more convenient to connect multiple devices to the remote PC.
```
+-------------------+                             +---------------------------+
|                   |                             |                           |
|      Host PC      |--- SSH Connection --------->|         Remote PC         |
|                   |                             |                           |
+-------------------+                             |–––––––––––––––––––––––––––|
                                                  | source_netns | sink_netns |
                                                  +---------------------------+
                                                          |            Ʌ
                                                          |            |
                                                          |            |
                                                          V            |
+------------------------------------------------------------------------------+
|                                                                              |
|                                                                              |
|                             Network Switch                                   |
|                                                                              |
|                                                                              |
+------------------------------------------------------------------------------+
   |   Ʌ         |   Ʌ         |   Ʌ         |   Ʌ         |   Ʌ
   |   |         |   |         |   |         |   |         |   |
   |   |         |   |         |   |         |   |         |   |
   V   |         V   |         V   |         V   |         V   |
+----------+  +----------+  +----------+  +----------+  +----------+
|          |  |          |  |          |  |          |  |          |
| Device 1 |  | Device 2 |  | Device 3 |  | Device 4 |  | Device n |
|          |  |          |  |          |  |          |  |          |
+----------+  +----------+  +----------+  +----------+  +----------+
```
<br>

Adjustable settings via <a href="https://github.com/tk154/GSoC2024_eBPF-Firewall/blob/main/measurement/settings.json">settings.json</a>:
| JSON Setting         | Explanation |
| :------------------: | :---------- |
| ssh_name             | The configured Host of ~/.ssh/config from the remote PC. That can also be the localhost if you want so. |
| devices              | The to be tested OpenWrt devices |
| port                 | ```iperf3``` server listening port |
| options              | Other ```iperf3``` client and server options |
| parts                | Firewall (offloading) settings measured in an ```iperf3``` run |
| seconds_per_part     | How long an ```iperf3``` run should run per part in seconds |
| seconds_before_parts | How long the script should wait before beginning an ```iperf3``` run in seconds |
<br>

The bash script <a href="https://github.com/tk154/GSoC2024_eBPF-Firewall/blob/main/measurement/transfer_files.sh">transfer_files.sh</a>, which you should run before running the measurement script, copies the ipv4_forward eBPF object files and two OpenWrt scripts to the in ```settings.json``` configured devices. The OpenWrt ash script <a href="https://github.com/tk154/GSoC2024_eBPF-Firewall/blob/main/measurement/openwrt/set_fw.sh">set_fw.sh</a> switches between the firewall (offloading) settings, and the awk script <a href="https://github.com/tk154/GSoC2024_eBPF-Firewall/blob/main/measurement/openwrt/cpu_stats.awk">cpu_stats.awk</a> measures and prints the CPU load per core every second.

To start a measurement run, you can run the <a href="https://github.com/tk154/GSoC2024_eBPF-Firewall/blob/main/measurement/measurement.sh">measurement.sh</a> bash script. ```jq``` is required on the host to read the ```settings.json``` file. On the remote PC, you must install ```iperf3```, ```tcpdump```, and ```tcpstat```.

After the script has finished, you should find a new folder under ```data/``` containing the measurement data. You can now plot this data using the R script <a href="https://github.com/tk154/GSoC2024_eBPF-Firewall/blob/main/measurement/plot.R">plot.R</a>. The additional packages ```ggplot2``` and ```rjson``` are required to plot the data.

After this script has finished, you should find a PDF file called ```Rplots.pdf``` containing the plots inside the measurement directory.
