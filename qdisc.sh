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
ip netns exec router ethtool -L r_veth tx 2
ip netns exec router ethtool -l r_veth

# Add the mq classful qdisc, and add two separate queues
# TODO: make this cli-arg!!!
sudo ip netns exec router tc qdisc add dev r_veth root handle 1 mq
sudo ip netns exec router tc qdisc add dev r_veth parent 1:1 handle 2: fq_pie
sudo ip netns exec router tc qdisc add dev r_veth parent 1:2 handle 2: fq_codel

# Verify changes
sudo ip netns exec router tc qdisc show

# Add filter!
