#!/bin/bash

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
sudo ip netns exec router ethtool -L r_veth tx 2
sudo ip netns exec router ethtool -l r_veth

# Add the mq classful qdisc, and add two separate queues
# TODO: make this cli-arg!!!
# Create the root mq qdisc with handle 1:
sudo ip netns exec router tc qdisc add dev r_veth root handle 1: mq
# Create two classes under the mq qdisc
# Attach fq_pie to the first class
sudo ip netns exec router tc qdisc add dev r_veth parent 1:1 handle 10: fq_pie
# Attach fq_codel to the second class
sudo ip netns exec router tc qdisc add dev r_veth parent 1:2 handle 20: fq_codel
# Add clsact: surprise???
sudo ip netns exec router tc qdisc add dev r_veth clsact

# Verify changes
sudo ip netns exec router tc qdisc show



# Add filter!
# sudo ip netns exec router tc filter add dev r_veth parent 1: protocol ip prio 1 u32 match ip dst 192.168.1.2/24 flowid 1:1
# sudo ip netns exec router tc filter add dev r_veth parent 1: protocol ip prio 2 matchall flowid 1:2
# sudo ip netns exec router tc filter show
sudo ip netns exec router tc filter add dev r_veth egress protocol ip prio 1 u32 \
    match ip dst 192.168.1.2/24 \
    action skbedit queue_mapping 0

sudo ip netns exec router tc filter add dev r_veth egress protocol ip prio 2 u32 \
    match u32 0 0 \
    action skbedit queue_mapping 1

echo -e "\n"

# Show filters
sudo ip netns exec router tc -s filter show dev r_veth egress

echo -e "\n"

# Show qdisc stats
sudo ip netns exec router tc -s qdisc show dev r_veth