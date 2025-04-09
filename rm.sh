#!/bin/bash

netns_array=($(ip netns list))

for ns in "${netns_array[@]}"; do
    echo "Namespace: $ns deleted"
    sudo ip netns delete $ns
done

sudo ip link delete switch

echo List of Network Namespaces:
ip netns list

echo List of Switches:
ip link show | grep switch