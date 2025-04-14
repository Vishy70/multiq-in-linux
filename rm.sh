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

ip link delete switch

echo List of Switches:
ip link show | grep switch

# Switch cable links remain after deleting the switch
ip link delete s1_veth
ip link delete s2_veth


#to leave some lines for cuteness
echo "-----------------------------------------------------------------------------------------------------------------------"
echo
