#!/bin/bash

echo -e "\e[34m Qdisc  \e[0m"

# Define colors for better readability in logs
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color


# Read tx rings present on rs_veth... change it to 2
ip netns exec router ethtool -L r_veth tx 2
ip netns exec router ethtool -l r_veth

# adding multiq
sudo ip netns exec router tc qdisc add dev r_veth root handle 1: multiq

# CHANGES HERE!
#-----------------------------------------------------------------------------------------------------------------------

# Attach fq_pie to the first class
# sudo ip netns exec router tc qdisc add dev r_veth parent 1:1 handle 10: fq_pie

# Attach tbf to priority queue, another source of confirmation via traffic shaping, which can be confirmed with iperf!
sudo ip netns exec router tc qdisc add dev r_veth parent 1:1 handle 10: tbf latency 70ms burst 5kb rate 1.5mbit 

# Attach fq_codel to the second class
sudo ip netns exec router tc qdisc add dev r_veth parent 1:2 handle 20: fq_codel

#-----------------------------------------------------------------------------------------------------------------------

# Verify changes
echo
echo "Router's Qdisc Configuration at r_veth"
sudo ip netns exec router tc -s qdisc show dev r_veth



#to leave some lines for cuteness
echo "-----------------------------------------------------------------------------------------------------------------------"
echo
