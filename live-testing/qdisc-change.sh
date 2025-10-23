#!/bin/bash

baseline=$1
dev_name=$2
serial_num=$3
QDISC_1=$4
QDISC_2=$5

if [ $baseline = "true" ];
then
    #ifbcs_root=$(sudo ip netns exec router tc qdisc show dev ifbcs handle 1: 2>/dev/null | awk '/[[:space:]]root[[:space:]]/ {print $2; exit}')
    #ifbsc_root=$(sudo ip netns exec router tc qdisc show dev ifbsc handle 1: 2>/dev/null | awk '/[[:space:]]root[[:space:]]/ {print $2; exit}')

    ./adb -s $serial_num shell tc qdisc del dev $dev_name root handle 1:
    
    ./adb -s $serial_num shell tc qdisc add dev $dev_name root handle 1: $QDISC_1
else
    # Attach QDISC_1 to the first class
    # Attach QDISC_2 to the second class
    #ifbcs_child1=$(sudo ip netns exec router tc qdisc show dev ifbcs handle 10: 2>/dev/null | awk '/[[:space:]]parent[[:space:]]/ {print $2; exit}')
    #ifbcs_child2=$(sudo ip netns exec router tc qdisc show dev ifbcs handle 20: 2>/dev/null | awk '/[[:space:]]parent[[:space:]]/ {print $2; exit}')

    ./adb -s $serial_num shelltc qdisc del dev $dev_name parent 1:1 handle 10:
    ./adb -s $serial_num shelltc qdisc del dev $dev_name parent 1:2 handle 20:
    ./adb -s $serial_num shelltc qdisc add dev $dev_name parent 1:1 handle 10: $QDISC_1
    ./adb -s $serial_num shelltc qdisc add dev $dev_name parent 1:2 handle 20: $QDISC_2

fi

if [ $? -eq 2 ]
then
    echo "Possible error?!"
    echo "Specified qdiscs: $QDISC_1, $QDISC_2"
    exit 2
fi

exit 0