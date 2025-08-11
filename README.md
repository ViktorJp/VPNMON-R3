# VPNMON-R3 v1.6.0 Beta 1
Asus-Merlin OpenVPN/Wireguard Monitor R3

Updated on 2025-Aug-11

---

<img width="1013" height="790" alt="image" src="https://github.com/user-attachments/assets/38482b93-137d-457b-bb12-e77129187d73" />

---

**EXECUTIVE SUMMARY:** VPNMON-R3 (vpnmon-r3.sh) is an all-in-one script that is optimized to maintain multiple OpenVPN and Wireguard connections and is able to provide for the capabilities to randomly reconnect using a specified server list containing the servers of your choice. Special care has been taken to ensure that only the connections you want to have monitored are tended to. This script will check the health of up to 5 VPN and 5 Wireguard connections on a regular interval to see if monitored connections are stable, and sends a ping to a host of your choice through each active connection. If it finds that a connection has been lost, it will execute a series of commands that will kill that single client, and randomly picks one of your specified servers to reconnect to for each client. It also monitors your WAN/Dual-WAN connection and drops back until your WAN connection comes back up to reconnect your VPN/WG tunnels.
