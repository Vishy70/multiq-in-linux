#!/bin/bash

echo -e "\e[34m Filters  \e[0m"

#ref for filters: https://www.kernel.org/doc/html/v5.8/networking/multiqueue.html

sudo ip netns exec router tc filter add dev r_veth parent 1: protocol ip prio 1 u32 match ip dst 192.168.1.3 action skbedit queue_mapping 0
sudo ip netns exec router tc filter add dev r_veth parent 1: protocol ip prio 2 matchall action skbedit queue_mapping 1

# sudo ip netns exec router tc filter add dev r_veth parent 1: protocol ip prio 2 matchall action skbedit queue_mapping 1

echo
echo "Router's Filter Configuration "
sudo ip netns exec router tc -s filter show dev r_veth parent 1:

#to leave some lines for cuteness
echo "-----------------------------------------------------------------------------------------------------------------------"
echo