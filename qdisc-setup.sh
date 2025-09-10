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

if [ $baseline = "false" ];
then
    # adding multiq
    sudo ip netns exec router tc qdisc replace dev r_veth root handle 1: multiq
else
    sudo ip netns exec router tc qdisc add dev r_veth root pfifo
    sudo ip netns exec routerbw tc qdisc add dev rbw_veth root netem rate 10mbit
    sudo ip netns exec routerbw tc qdisc add dev rrbw_veth root netem rate 10mbit
fi

# Verify changes
echo
echo "Router's Qdisc Configuration at r_veth"
sudo ip netns exec router tc -s qdisc show dev r_veth

echo "-----------------------------------------------------------------------------------------------------------------------"
echo

exit 0
