#!/bin/bash

# Create the 5 namespaces:
# - 2 clients
# - 1 router
# - 2 servers
echo -e "\e[34mSetup of Namespaces and Switch  \e[0m"

sudo ip netns add client1
sudo ip netns add client2
sudo ip netns add router
sudo ip netns add server1
sudo ip netns add server2

# Create a real linux bridge
sudo ip link add name switchcr type bridge
sudo ip link add name switchrs type bridge
sudo ip link set switchcr up
sudo ip link set switchrs up

# Check for successful creation
echo "List of devices (Network Namespaces)":
ip netns list
echo -e "\n"

echo "List of Switches (Bridges)":
ip link show | grep switch
echo -e "\n"

# Create vethernet cables
sudo ip link add c1_veth type veth peer name c1swcr_veth
sudo ip link add c2_veth type veth peer name c2swcr_veth
sudo ip link add swcr_veth type veth peer name cr_veth
sudo ip link add rs_veth type veth peer name swrs_veth
sudo ip link add swrss1_veth type veth peer name s1_veth
sudo ip link add swrss2_veth type veth peer name s2_veth

# Put the switch cables in the linux bridge!
sudo ip link set swcr_veth up
sudo ip link set swrs_veth up
sudo ip link set c1swcr_veth up
sudo ip link set c2swcr_veth up
sudo ip link set swrss1_veth up
sudo ip link set swrss2_veth up

sudo ip link set swcr_veth master switchcr
sudo ip link set c1swcr_veth master switchcr
sudo ip link set c2swcr_veth master switchcr
sudo ip link set swrs_veth master switchrs
sudo ip link set swrss1_veth master switchrs
sudo ip link set swrss2_veth master switchrs

# Put the cables in the netns...
sudo ip link set c1_veth netns client1
sudo ip link set c2_veth netns client2
sudo ip link set cr_veth netns router
sudo ip link set rs_veth netns router
sudo ip link set s1_veth netns server1
sudo ip link set s2_veth netns server2

# ...give the interfaces static IP addresses
sudo ip netns exec client2 ip a add 192.168.2.3/24 dev c2_veth
sudo ip netns exec client1 ip a add 192.168.2.2/24 dev c1_veth
sudo ip netns exec router ip a add 192.168.2.1/24 dev cr_veth
sudo ip netns exec router ip a add 192.168.1.1/24 dev rs_veth
sudo ip netns exec server1 ip a add 192.168.1.2/24 dev s1_veth
sudo ip netns exec server2 ip a add 192.168.1.3/24 dev s2_veth

# The swcr_veth does not need an IP address, since it is connected to a switch
# The c1swcr_veth does not need an IP address, since it is connected to a switch
# The c2swcr_veth does not need an IP address, since it is connected to a switch
# The swrs_veth does not need an IP address, since it is connected to a switch
# The swrss1_veth does not need an IP address, since it is connected to a switch
# The swrss2_veth does not need an IP address, since it is connected to a switch

# and bring them up...
sudo ip netns exec client2 ip link set dev c2_veth up
sudo ip netns exec client1 ip link set dev c1_veth up
sudo ip netns exec router ip link set dev cr_veth up
sudo ip netns exec router ip link set dev rs_veth up
sudo ip netns exec server1 ip link set dev s1_veth up
sudo ip netns exec server2 ip link set dev s2_veth up

# Also bring up loopback interface
sudo ip netns exec client1 ip link set dev lo up
sudo ip netns exec client2 ip link set dev lo up
sudo ip netns exec router ip link set dev lo up
sudo ip netns exec server1 ip link set dev lo up
sudo ip netns exec server2 ip link set dev lo up

#Verify that they are in the respective namespaces/bridge
sudo ip -all netns exec ip a
echo -e "\n"
bridge link show
echo -e "\n"

#Ensure that the router can forward
sudo ip netns exec router sysctl -w net.ipv4.ip_forward=1
echo -e "\n"

# Add default routes to client, server1, server2
sudo ip netns exec client1 ip route add default via 192.168.2.1 dev c1_veth
sudo ip netns exec client2 ip route add default via 192.168.2.1 dev c2_veth
sudo ip netns exec server1 ip route add default via 192.168.1.1 dev s1_veth
sudo ip netns exec server2 ip route add default via 192.168.1.1 dev s2_veth

# Add iptables rules to allow traffic crossing the client-router-server bridges through
# Temporary rules that does not mess with docker iptables config
sudo iptables -I FORWARD -i switchcr -j ACCEPT
sudo iptables -I FORWARD -o switchcr -j ACCEPT
sudo iptables -I FORWARD -i switchrs -j ACCEPT
sudo iptables -I FORWARD -o switchrs -j ACCEPT

# Ensure the default route is added!
echo Client1 Routes:
sudo ip netns exec client1 ip route
echo -e "\n"
echo Client2 Routes:
sudo ip netns exec client2 ip route
echo -e "\n"
echo Server1 Routes:
sudo ip netns exec server1 ip route
echo -e "\n"
echo Server2 Routes:
sudo ip netns exec server2 ip route
echo -e "\n"
echo Router Routes:
sudo ip netns exec router ip route
echo -e "\n"

echo "-----------------------------------------------------------------------------------------------------------------------"
exit 0