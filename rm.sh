#!/bin/bash
# Print in blue
echo -e "\e[34mClearing any existing namespaces and switches \e[0m"

# Remove iptables rules for the client-router-server bridges
sudo iptables -D FORWARD -i switchcr -j ACCEPT 2>/dev/null
sudo iptables -D FORWARD -o switchcr -j ACCEPT 2>/dev/null
sudo iptables -D FORWARD -i switchrs -j ACCEPT 2>/dev/null
sudo iptables -D FORWARD -o switchrs -j ACCEPT 2>/dev/null

netns_array=($(ip netns list | awk '{print $1}'))
for ns in "${netns_array[@]}"; do
    sudo ip netns delete $ns
done

bridges_and_interfaces=($(ip link show | awk '/switch/ {gsub(/:|@.*/, "", $2); print $2}'))
for iface in "${bridges_and_interfaces[@]}"; do
    sudo ip link delete $iface
done

echo List of Network Namespaces:
ip netns list

echo List of Switches:
ip link show | grep switch

echo "-----------------------------------------------------------------------------------------------------------------------"
echo
exit 0
