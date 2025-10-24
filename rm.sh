#!/bin/bash
# Print in blue
echo -e "\e[34mClearing any existing namespaces and switches \e[0m"

netns_array=($(ip netns list))

for ns in "${netns_array[@]}"; do
    # echo "Namespace: $ns deleted"
    ip netns delete $ns
done

echo List of Network Namespaces:
ip netns list

ip link delete switchcr
ip link delete switchrs
ip link delete client1
ip link delete client2
ip link delete server1
ip link delete server2
ip link delete router

echo List of Switches:
ip link show | grep switch

# Switch cable links remain after deleting the switch
ip link delete s1_veth
ip link delete s2_veth
ip link delete c1swcr_veth
ip link delete c2swcr_veth
ip link delete swcr_veth
ip link delete swrs_veth
ip link delete cr_veth
ip link delete rs_veth
ip link delete c1_veth
ip link delete c2_veth
ip link delete r_veth
ip link delete swrss1_veth
ip link delete swrss2_veth


echo "-----------------------------------------------------------------------------------------------------------------------"
echo
exit 0
