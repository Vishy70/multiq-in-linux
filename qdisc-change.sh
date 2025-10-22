#!/bin/bash

baseline=$1
QDISC_1=$2
QDISC_2=$3

if [ $baseline = "true" ];
then
    #ifbcs_root=$(sudo ip netns exec router tc qdisc show dev ifbcs handle 1: 2>/dev/null | awk '/[[:space:]]root[[:space:]]/ {print $2; exit}')
    #ifbsc_root=$(sudo ip netns exec router tc qdisc show dev ifbsc handle 1: 2>/dev/null | awk '/[[:space:]]root[[:space:]]/ {print $2; exit}')

    sudo ip netns exec router tc qdisc del dev ifbcs root handle 1:
    sudo ip netns exec router tc qdisc del dev ifbsc root handle 1:
    
    sudo ip netns exec router tc qdisc add dev ifbcs root handle 1: $QDISC_1
    sudo ip netns exec router tc qdisc add dev ifbsc root handle 1: $QDISC_1
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

if [ $? -eq 2 ]
then
    echo "Possible error?!"
    echo "Specified qdiscs: $QDISC_1, $QDISC_2"
    exit 2
fi

exit 0