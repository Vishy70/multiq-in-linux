#!/bin/bash

SERVER1_IP="$1"
dev_name=$2
serial_num=$3

echo -e "\e[34m Filters \e[0m"

#ref for filters: https://www.kernel.org/doc/html/v5.8/networking/multiqueue.html

./adb -s $serial_num shell tc filter add dev $dev_name parent 1: protocol ip prio 1 u32 match ip dst $SERVER1_IP action skbedit queue_mapping 0
./adb -s $serial_num shell tc filter add dev $dev_name parent 1: protocol ip prio 2 matchall action skbedit queue_mapping 1

#./adb -s $serial_num shell tc filter add dev $dev_name parent 1: protocol ip prio 1 u32 match ip dst $SERVER1_IP action skbedit queue_mapping 0
#./adb -s $serial_num shell tc filter add dev $dev_name parent 1: protocol ip prio 2 matchall action skbedit queue_mapping 1

# sudo ip netns exec router tc filter add dev r_veth parent 1: protocol ip prio 2 matchall action skbedit queue_mapping 1

echo
echo "Router's Filter Configuration "
./adb -s $serial_num shell tc -s filter show dev $dev_name parent 1:

echo "-----------------------------------------------------------------------------------------------------------------------"
echo
exit 0
