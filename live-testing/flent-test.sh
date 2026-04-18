#!/bin/bash

qdisc="$1"
echo -e "Using qdisc: $qdisc\n"

iter="$2"
output_dir="$3"

NETSERVER_ADDRESS="netperf-west.bufferbloat.net"
TEST_LENGTH=300

RRUL_DIR="$output_dir/rrul"
mkdir -p $RRUL_DIR
RRUL_TEST_NAME="rrul_${qdisc}_${TEST_LENGTH}"
echo -e "Running rrul test with qdisc=$qdisc...\n"

# RRUL TEST
flent rrul -H "$NETSERVER_ADDRESS" --length="$TEST_LENGTH" -f csv --output="${RRUL_DIR}/${iter}-${RRUL_TEST_NAME}.csv"

# List of number of TCP streams for tcp_ndown test
DOWNLOAD_STREAMS=(10 25 50 75 100 200)

for n in "${DOWNLOAD_STREAMS[@]}"; do
    TCP_NDOWN_DIR="$output_dir/tcp_${n}down"
    mkdir -p $TCP_NDOWN_DIR
    TCP_NDOWN_TEST_NAME="tcp_${n}down_${qdisc}_${TEST_LENGTH}"
    echo -e "\nRunning tcp_ndown test with n=$n, qdisc=$qdisc...\n"

    # TCP_NDOWN Test
    flent tcp_ndown --test-parameter=download_streams="$n" -H "$NETSERVER_ADDRESS" --length="$TEST_LENGTH" -f csv --output="${TCP_NDOWN_DIR}/${iter}-${TCP_NDOWN_TEST_NAME}.csv"
done
