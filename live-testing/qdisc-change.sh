#!/bin/bash

baseline=$1
dev_name=$2
serial_num=$3
QDISC_1=$4
QDISC_2=$5

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

exit 0