#!/bin/bash

# Create the 5 namespaces:
# - 2 clients
# - 1 router
# - 2 servers
echo -e "\e[34m Setup of Namespaces and Switch  \e[0m"

ip netns add client1
ip netns add client2
ip netns add router
ip netns add server1
ip netns add server2

# Create a real linux bridge
ip link add name switchcr type bridge
ip link add name switchrs type bridge
ip link set switchcr up
ip link set switchrs up

# Check for successful creation
echo "List of devices (Network Namespaces)":
ip netns list
echo -e "\n"

echo "List of Switches (Bridges)":
ip link show | grep switch
echo -e "\n"

# Create vethernet cables
ip link add c1_veth type veth peer name c1swcr_veth
ip link add c2_veth type veth peer name c2swcr_veth
ip link add swcr_veth type veth peer name cr_veth
ip link add rs_veth type veth peer name swrs_veth
ip link add swrss1_veth type veth peer name s1_veth
ip link add swrss2_veth type veth peer name s2_veth

# Put the switch cables in the linux bridge!
ip link set swcr_veth up
ip link set swrs_veth up
ip link set c1swcr_veth up
ip link set c2swcr_veth up
ip link set swrss1_veth up
ip link set swrss2_veth up

ip link set swcr_veth master switchcr
ip link set c1swcr_veth master switchcr
ip link set c2swcr_veth master switchcr
ip link set swrs_veth master switchrs
ip link set swrss1_veth master switchrs
ip link set swrss2_veth master switchrs

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

# The rs_veth does not need an IP address, since it is connected to a switch
# The s1_veth does not need an IP address, since it is connected to a switch
# The s2_veth does not need an IP address, since it is connected to a switch

sudo ip netns exec server1 ip a add 192.168.1.2/24 dev s1_veth
sudo ip netns exec server2 ip a add 192.168.1.3/24 dev s2_veth

# and bring them up...
sudo ip netns exec client1 ip link set dev c1_veth up
sudo ip netns exec client2 ip link set dev c2_veth up
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
ip -all netns exec ip a
echo -e "\n"
bridge link show switch
echo -e "\n"

#Ensure that the router can forward
ip netns exec router sysctl -w net.ipv4.ip_forward=1
#ip netns exec routerbw sysctl -w net.ipv4.ip_forward=1
echo -e "\n"

# Add default routes to client, server1, server2
sudo ip netns exec client1 ip route add default via 192.168.2.1 dev c1_veth
sudo ip netns exec client2 ip route add default via 192.168.2.1 dev c2_veth
sudo ip netns exec server1 ip route add default via 192.168.1.1 dev s1_veth
sudo ip netns exec server2 ip route add default via 192.168.1.1 dev s2_veth

# Add extra route in router to forward to servers
# sudo ip netns exec router ip route add 192.168.1.0/24 via 192.168.1.1 dev r_veth
# sudo ip netns exec router ip route add 192.168.2.0/24 via 192.168.1.2 dev c1r_veth
# sudo ip netns exec router ip route add 192.168.3.0/24 via 192.168.1.2 dev c2r_veth


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
echo -e "\n"

echo "-----------------------------------------------------------------------------------------------------------------------"
echo
exit 0