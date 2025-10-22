#!/bin/bash

SERVER1_IP="192.168.2.2"

echo -e "\e[34m Filters \e[0m"

#ref for filters: https://www.kernel.org/doc/html/v5.8/networking/multiqueue.html

sudo ip netns exec router tc filter add dev ifbcs parent 1: protocol ip prio 1 u32 match ip src $SERVER1_IP action skbedit queue_mapping 0
sudo ip netns exec router tc filter add dev ifbcs parent 1: protocol ip prio 2 matchall action skbedit queue_mapping 1

sudo ip netns exec router tc filter add dev ifbsc parent 1: protocol ip prio 1 u32 match ip src $SERVER1_IP action skbedit queue_mapping 0
sudo ip netns exec router tc filter add dev ifbsc parent 1: protocol ip prio 2 matchall action skbedit queue_mapping 1

# sudo ip netns exec router tc filter add dev r_veth parent 1: protocol ip prio 2 matchall action skbedit queue_mapping 1

echo
echo "Router's Filter Configuration "
sudo ip netns exec router tc -s filter show dev ifbcs parent 1:
sudo ip netns exec router tc -s filter show dev ifbsc parent 1:

echo "-----------------------------------------------------------------------------------------------------------------------"
echo
exit 0
