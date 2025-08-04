#!/bin/bash

NEW_QDISC = $1

# Attach pfifo to the first class ALWAYS
sudo ip netns exec router tc qdisc add dev r_veth parent 1:1 handle 10: pfifo
# Attach NEW_QDISC to the second class
sudo ip netns exec router tc qdisc add dev r_veth parent 1:2 handle 20: $NEW_QDISC

if [ $? -eq 2 ]
then

    echo "Specified qdisc: $NEW_QDISC"
    exit 2
fi

exit 0