#!/bin/bash

echo -e "\e[34mQdisc  \e[0m"

virtual="$1"
baseline="$2"
dev_name="$3"
serial_num="$4"

if [ $virtual = true ];
then
    rings=2
    if [ $baseline = true ];
    then
        rings=1
    fi

    # Add ifb: For adding real qdiscs to test; netem is added to veth, in similar fashion to NeST
    sudo ip netns exec router ip link del ifbcs
    sudo ip netns exec router ip link del ifbsc
    sudo ip link add numtxqueues $rings ifbcs type ifb
    sudo ip link add numtxqueues $rings ifbsc type ifb

    # Put ifb in the netns...
    sudo ip link set ifbcs netns router
    sudo ip link set ifbsc netns router

    sudo ip netns exec router ip link set dev ifbcs up
    sudo ip netns exec router ip link set dev ifbsc up

    # Read tx rings present on ifbcs and ifbsc
    echo "Number of tx rings, towards server: $(sudo ip netns exec router ls /sys/class/net/ifbcs/queues | grep tx | wc -l)"
    echo "Number of tx rings, towards client: $(sudo ip netns exec router ls /sys/class/net/ifbsc/queues | grep tx | wc -l)"

    if [ $baseline = "false" ];
    then
        # adding multiq
        #sudo ip netns exec router tc qdisc del dev ifbcs root handle 1:
        #sudo ip netns exec router tc qdisc del dev ifbsc root handle 1:
        
        sudo ip netns exec router tc qdisc add dev ifbcs root handle 1: multiq
        sudo ip netns exec router tc qdisc add dev ifbsc root handle 1: multiq
        
        sudo ip netns exec router tc qdisc add dev ifbcs parent 1:1 handle 10: pfifo
        sudo ip netns exec router tc qdisc add dev ifbcs parent 1:2 handle 20: pfifo
        sudo ip netns exec router tc qdisc add dev ifbsc parent 1:1 handle 10: pfifo
        sudo ip netns exec router tc qdisc add dev ifbsc parent 1:2 handle 20: pfifo
    else
        sudo ip netns exec router tc qdisc add dev ifbcs root handle 1: pfifo
        sudo ip netns exec router tc qdisc add dev ifbsc root handle 1: pfifo

        sudo ip netns exec router tc qdisc add dev cr_veth root handle 1: htb default 10
        sudo ip netns exec router tc qdisc add dev rs_veth root handle 1: htb default 10
        # Note: 100mbit is a dummy value... should be >> netem rate value!
        sudo ip netns exec router tc class add dev cr_veth parent 1: classid 1:10 htb rate 10mbit ceil 100mbit
        sudo ip netns exec router tc class add dev rs_veth parent 1: classid 1:10 htb rate 10mbit ceil 100mbit
        sudo ip netns exec router tc filter add dev cr_veth parent 1: protocol all u32 match u8 0 0 action mirred egress redirect dev ifbcs
        sudo ip netns exec router tc filter add dev rs_veth parent 1: protocol all u32 match u8 0 0 action mirred egress redirect dev ifbsc
        sudo ip netns exec router tc qdisc add dev cr_veth parent 1:10 handle 10: netem rate 5mbit loss 5%
        sudo ip netns exec router tc qdisc add dev rs_veth parent 1:10 handle 10: netem rate 5mbit loss 5%
    fi

    # Verify changes
    echo
    echo "Router's Qdisc Configuration at cr_veth"
    sudo ip netns exec router tc -s qdisc show dev cr_veth
    echo -e "\n"

    echo "Router's Qdisc Configuration at rs_veth"
    sudo ip netns exec router tc -s qdisc show dev rs_veth
    echo -e "\n"

    echo "Router's Qdisc Configuration at ifbcs"
    sudo ip netns exec router tc -s qdisc show dev ifbcs
    echo -e "\n"

    echo "Router's Qdisc Configuration at ifbsc"
    sudo ip netns exec router tc -s qdisc show dev ifbsc
    echo -e "\n"

else
    if [ $baseline = "false" ];
    then
        # adding multiq
        ./adb -s $serial_num shell tc qdisc del dev $dev_name root handle 1:
        ./adb -s $serial_num shell tc qdisc add dev $dev_name root handle 1: multiq
        ./adb -s $serial_num shell tc qdisc add dev $dev_name parent 1:1 handle 10: pfifo
        ./adb -s $serial_num shell tc qdisc add dev $dev_name parent 1:2 handle 20: pfifo
    else
        ./adb -s $serial_num shell tc qdisc del dev $dev_name clsact
        if [[ $? = 2 ]];
        then
            echo "Immediately previous Invalid argument error is due to clsact already being deleted"
        fi
        ./adb -s $serial_num shell tc qdisc del dev $dev_name root
    fi

    # Verify changes
    echo
    echo "Router's Qdisc Configuration at $dev_name"
    sudo ./adb -s $serial_num shell tc qdisc show dev $dev_name
fi

echo "-----------------------------------------------------------------------------------------------------------------------"
exit 0