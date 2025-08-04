#!/bin/bash

echo -e "\e[34m Qdisc  \e[0m"

baseline="$1"
rings=2

if [ $baseline = "true" ];
then
    rings=1
fi

# Read tx rings present on rs_veth... change it to 2
ip netns exec router ethtool -L r_veth tx "$rings"
ip netns exec router ethtool -l r_veth

if [ baseline = "false" ];
then
    # adding multiq
    sudo ip netns exec router tc qdisc add dev r_veth root handle 1: multiq
fi

# Verify changes
echo
echo "Router's Qdisc Configuration at r_veth"
sudo ip netns exec router tc -s qdisc show dev r_veth

echo "-----------------------------------------------------------------------------------------------------------------------"
echo

exit 0
