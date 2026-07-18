#!/bin/bash

virtual="$1"
SERVER1_IP="$2"
dev_name=$3
serial_num=$4

echo -e "\e[34mFilters\e[0m"

#ref for filters: https://www.kernel.org/doc/html/v5.8/networking/multiqueue.html
if [[ "$virtual" = "true" ]];
then
    sudo ip netns exec router tc filter add dev ifbcs parent 1: protocol ip prio 1 u32 match ip src $SERVER1_IP action skbedit queue_mapping 0
    sudo ip netns exec router tc filter add dev ifbcs parent 1: protocol ip prio 2 matchall action skbedit queue_mapping 1

    sudo ip netns exec router tc filter add dev ifbsc parent 1: protocol ip prio 1 u32 match ip src $SERVER1_IP action skbedit queue_mapping 0
    sudo ip netns exec router tc filter add dev ifbsc parent 1: protocol ip prio 2 matchall action skbedit queue_mapping 1

    # sudo ip netns exec router tc filter add dev r_veth parent 1: protocol ip prio 2 matchall action skbedit queue_mapping 1

    echo "Router's Filter Configuration "
    sudo ip netns exec router tc -s filter show dev ifbcs parent 1:
    sudo ip netns exec router tc -s filter show dev ifbsc parent 1:
else
    ./adb -s $serial_num shell tc filter add dev $dev_name parent 1: protocol ip prio 1 u32 match ip dst $SERVER1_IP action skbedit queue_mapping 0
    ./adb -s $serial_num shell tc filter add dev $dev_name parent 1: protocol ip prio 2 matchall action skbedit queue_mapping 1

    # sudo ip netns exec router tc filter add dev r_veth parent 1: protocol ip prio 2 matchall action skbedit queue_mapping 1

    echo
    echo "Router's Filter Configuration "
    ./adb -s $serial_num shell tc -s filter show dev $dev_name parent 1:
fi

echo "-----------------------------------------------------------------------------------------------------------------------"
exit 0
