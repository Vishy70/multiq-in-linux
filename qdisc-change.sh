#!/bin/bash

virtual="$1"
baseline="$2"
QDISC_1="$3"
QDISC_2="$4"
dev_name="$5"
serial_num="$6"

if [ "$virtual" = "true" ];
then
    if [ $baseline = "true" ];
    then

        sudo ip netns exec router tc qdisc del dev ifbcs root handle 1:
        sudo ip netns exec router tc qdisc del dev ifbsc root handle 1:
        
        sudo ip netns exec router tc qdisc add dev ifbcs root handle 1: $QDISC_1
        sudo ip netns exec router tc qdisc add dev ifbsc root handle 1: $QDISC_1

        # Verify changes
        echo
        echo "Router's Qdisc Configuration at ifbcs"
        sudo ip netns exec router tc -s qdisc show dev ifbcs
        echo -e "\n"

        echo "Router's Qdisc Configuration at ifbsc"
        sudo ip netns exec router tc -s qdisc show dev ifbsc
        echo -e "\n"
    else
        # Attach QDISC_1 to the first class
        # Attach QDISC_2 to the second class
        #ifbcs_child1=$(sudo ip netns exec router tc qdisc show dev ifbcs handle 10: 2>/dev/null | awk '/[[:space:]]parent[[:space:]]/ {print $2; exit}')
        #ifbcs_child2=$(sudo ip netns exec router tc qdisc show dev ifbcs handle 20: 2>/dev/null | awk '/[[:space:]]parent[[:space:]]/ {print $2; exit}')

        sudo ip netns exec router tc qdisc del dev ifbcs parent 1:1 handle 10:
        sudo ip netns exec router tc qdisc del dev ifbcs parent 1:2 handle 20:
        sudo ip netns exec router tc qdisc add dev ifbcs parent 1:1 handle 10: $QDISC_1
        sudo ip netns exec router tc qdisc add dev ifbcs parent 1:2 handle 20: $QDISC_2

        # Attach QDISC_1 to the first class
        # Attach QDISC_2 to the second class
        #ifbsc_child1=$(sudo ip netns exec router tc qdisc show dev ifbsc handle 10: 2>/dev/null | awk '/[[:space:]]parent[[:space:]]/ {print $2; exit}')
        #ifbsc_child2=$(sudo ip netns exec router tc qdisc show dev ifbsc handle 20: 2>/dev/null | awk '/[[:space:]]parent[[:space:]]/ {print $2; exit}')

        sudo ip netns exec router tc qdisc del dev ifbsc parent 1:1 handle 10:
        sudo ip netns exec router tc qdisc del dev ifbsc parent 1:2 handle 20:
        sudo ip netns exec router tc qdisc add dev ifbsc parent 1:1 handle 10: $QDISC_1
        sudo ip netns exec router tc qdisc add dev ifbsc parent 1:2 handle 20: $QDISC_2
    fi
else
    if [ $baseline = "true" ];
    then
        ./adb -s $serial_num shell tc qdisc del dev $dev_name root handle 1:
        ./adb -s $serial_num shell tc qdisc add dev $dev_name root handle 1: $QDISC_1
    else
        ./adb -s $serial_num shell tc qdisc del dev $dev_name parent 1:1 handle 10:
        ./adb -s $serial_num shell tc qdisc del dev $dev_name parent 1:2 handle 20:
        ./adb -s $serial_num shell tc qdisc add dev $dev_name parent 1:1 handle 10: $QDISC_1
        ./adb -s $serial_num shell tc qdisc add dev $dev_name parent 1:2 handle 20: $QDISC_2
    fi
    echo
    echo "Router's Qdisc Configuration at $dev_name"
    sudo ./adb -s $serial_num shell tc -s qdisc show dev $dev_name
fi

exit 0