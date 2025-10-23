#!/bin/bash

echo -e "\e[34m Qdisc  \e[0m"

baseline="$1"
dev_name="$2"
serial_num="$3"


if [ $baseline = "false" ];
then
    # adding multiq
    #ifbcs_root=$(sudo ip netns exec router tc qdisc show dev ifbcs handle 1: 2>/dev/null | awk '/[[:space:]]root[[:space:]]/ {print $2; exit}')
    #ifbsc_root=$(sudo ip netns exec router tc qdisc show dev ifbsc handle 1: 2>/dev/null | awk '/[[:space:]]root[[:space:]]/ {print $2; exit}')
    
    #sudo ip netns exec router tc qdisc del dev ifbcs root handle 1:
    #sudo ip netns exec router tc qdisc del dev ifbsc root handle 1:
    ./adb -s $serial_num shell tc qdisc del dev $dev_name root handle 1:
    ./adb -s $serial_num shell tc qdisc add dev $dev_name root handle 1: multiq
    ./adb -s $serial_num shell tc qdisc add dev $dev_name parent 1:1 handle 10: pfifo
    ./adb -s $serial_num shell tc qdisc add dev $dev_name parent 1:2 handle 20: pfifo
else
    ./adb -s $serial_num shell tc qdisc add dev $dev_name root handle 1: pfifo
fi

# Verify changes
echo
echo "Router's Qdisc Configuration at $dev_name"
sudo tc -s qdisc show dev $dev_name

echo "-----------------------------------------------------------------------------------------------------------------------"
echo

exit 0
