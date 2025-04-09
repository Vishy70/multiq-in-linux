#!/bin/bash

# Create the 4 namespaces
sudo ip netns add client
sudo ip netns add router
sudo ip netns add server1
sudo ip netns add server2
# Create a real linux bridge
sudo ip link add name switch type bridge
sudo ip link set switch up

# Check for successful creation
echo "List of devices (Network Namespaces)":
ip netns list
echo -e "\n"

echo "List of Switches (Bridges)":
ip link show | grep switch
echo -e "\n"

# Create vethernet cables
sudo ip link add c_veth type veth peer name cr_veth
sudo ip link add r_veth type veth peer name rs_veth
sudo ip link add s1_veth type veth peer name ss1_veth
sudo ip link add s2_veth type veth peer name ss2_veth

# Put the switch cables in the linux bridge!
sudo ip link set rs_veth up
sudo ip link set s1_veth up
sudo ip link set s2_veth up

sudo ip link set rs_veth master switch
sudo ip link set s1_veth master switch
sudo ip link set s2_veth master switch

# Put the cables in the netns...
sudo ip link set c_veth netns client
sudo ip link set cr_veth netns router
sudo ip link set r_veth netns router
sudo ip link set ss1_veth netns server1
sudo ip link set ss2_veth netns server2

# ...give the interfaces static IP addresses
sudo ip netns exec client ip a add 192.168.0.2/24 dev c_veth
sudo ip netns exec router ip a add 192.168.0.1/24 dev cr_veth
sudo ip netns exec router ip a add 192.168.1.1/24 dev r_veth
# The rs_veth does not need an IP address, since it is connected to a switch
# The s1_veth does not need an IP address, since it is connected to a switch
# The s2_veth does not need an IP address, since it is connected to a switch
sudo ip netns exec server1 ip a add 192.168.1.2/24 dev ss1_veth
sudo ip netns exec server2 ip a add 192.168.1.3/24 dev ss2_veth

# and bring them up...
sudo ip netns exec client ip link set dev c_veth up
sudo ip netns exec router ip link set dev cr_veth up
sudo ip netns exec router ip link set dev r_veth up
sudo ip netns exec server1 ip link set dev ss1_veth up
sudo ip netns exec server2 ip link set dev ss2_veth up

#Verify that they are in the respective namespaces/bridge
sudo ip -all netns exec ip a
echo -e "\n"
sudo bridge link show switch
echo -e "\n"

#Ensure that the router can forward
sudo ip netns exec router sysctl -w net.ipv4.ip_forward=1
echo -e "\n"

# Add default routes to client, server1, server2
sudo ip netns exec client ip route add default via 192.168.0.1 dev c_veth
sudo ip netns exec server1 ip route add default via 192.168.1.1 dev ss1_veth
sudo ip netns exec server2 ip route add default via 192.168.1.1 dev ss2_veth

# Ensure the default route is added!
echo Client Routes:
sudo ip netns exec client ip route
echo -e "\n"
echo Server1 Routes:
sudo ip netns exec server1 ip route
echo -e "\n"
echo Server2 Routes:
sudo ip netns exec server2 ip route
echo -e "\n"