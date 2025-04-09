#!/bin/bash

echo -e "\e[34m Qdisc  \e[0m"

# Define colors for better readability in logs
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Log function for error messages
log_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

# Log function for success messages
log_success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

# Check if router namespace exists
if ! ip netns list | grep -q "router"; then
    log_error "The 'router' network namespace does not exist!"
    log_error "Please create the network namespace before continuing."
    exit 1
else
    log_success "The 'router' network namespace exists. Script can continue."
fi

# Read tx rings present on rs_veth... change it to 2
ip netns exec router ethtool -L r_veth tx 2
ip netns exec router ethtool -l r_veth



# Add the mq classful qdisc, and add two separate queues
# TODO: make this cli-arg!!!
# Create the root mq qdisc with handle 1:
sudo ip netns exec router tc qdisc add dev r_veth root handle 1: multiq
# Create two classes under the mq qdisc
# Attach fq_pie to the first class
sudo ip netns exec router tc qdisc add dev r_veth parent 1:1 handle 10: fq_pie
# Attach fq_codel to the second class
sudo ip netns exec router tc qdisc add dev r_veth parent 1:2 handle 20: fq_codel

# Verify changes
echo
echo "Router's Qdisc Configuration at r_veth"
sudo ip netns exec router tc -s qdisc show dev r_veth

#ref for filters: https://www.kernel.org/doc/html/v5.8/networking/multiqueue.html

sudo ip netns exec router tc filter add dev r_veth parent 1: protocol ip prio 1 u32 match ip dst 192.168.1.3/32 action skbedit queue_mapping 0
sudo ip netns exec router tc filter add dev r_veth parent 1: protocol ip prio 2 matchall action skbedit queue_mapping 1

# sudo ip netns exec router tc filter add dev r_veth parent 1: protocol ip prio 2 matchall action skbedit queue_mapping 1

echo
echo "Router's Filter Configuration "
sudo ip netns exec router tc -s filter show dev r_veth parent 1:

# To see how many bytes how gone through each qdisc before running ping
# Need to make a function to offload the below  5 lines

echo "Packets (Bytes) Sent into fq_pie (handle 10:) "
ip netns exec router tc -s qdisc show dev r_veth | grep -A5 '10:' | grep 'Sent' | awk '{print $2}'
echo "Packets (Bytes) Sent into fq_codel (handle 20:) "
ip netns exec router tc -s qdisc show dev r_veth | grep -A5 '20:' | grep 'Sent' | awk '{print $2}'
echo

# sudo ip netns exec router tc -s qdisc show dev r_veth



echo "Pinging Packets from Client (192.168.0.2/24) to Server 1 (192.168.1.2/24)"
sudo ip netns exec client ping -s 5000 -c 5 192.168.1.2

# To see how many bytes how gone through each qdisc after ping from client to server 1
echo
echo "Packets (Bytes) Sent into fq_pie (handle 10:) "
ip netns exec router tc -s qdisc show dev r_veth | grep -A5 '10:' | grep 'Sent' | awk '{print $2}'
echo "Packets (Bytes) Sent into fq_codel (handle 20:) "
ip netns exec router tc -s qdisc show dev r_veth | grep -A5 '20:' | grep 'Sent' | awk '{print $2}'


# sudo ip netns exec router tc -s qdisc show dev r_veth



echo "Pinging Packets from Client (192.168.0.2/24) to Server 2 (192.168.1.3/24)"
sudo ip netns exec client ping -s 5000 -c 5 192.168.1.3


# To see how many bytes how gone through each qdisc after ping from client to server 1

echo
echo "Packets (Bytes) Sent into fq_pie (handle 10:) "
ip netns exec router tc -s qdisc show dev r_veth | grep -A5 '10:' | grep 'Sent' | awk '{print $2}'
echo "Packets (Bytes) Sent into fq_codel (handle 20:) "
ip netns exec router tc -s qdisc show dev r_veth | grep -A5 '20:' | grep 'Sent' | awk '{print $2}'
echo

sudo ip netns exec router tc -s qdisc show dev r_veth





