#!/bin/bash

# 1. Root prio qdisc with 2 bands (default is band 1, i.e., "low")
tc qdisc add dev eth0 root handle 1: prio bands 2

# 2. Attach TBF to the "high" priority band (band 0)
tc qdisc add dev eth0 parent 1:1 handle 10: tbf rate 1mbit burst 10kb latency 50ms

# 3. Attach FIFO (default pfifo_fast) to the "low" priority band (band 1)
tc qdisc add dev eth0 parent 1:2 handle 20: pfifo

# 4. Add a filter to classify certain packets to "high" priority
# Example: classify traffic from 192.168.1.100 as "high"
tc filter add dev eth0 protocol ip parent 1: prio 1 u32 \
  match ip src 192.168.1.100/32 flowid 1:1
