
# Initialize previous byte counts
prev_tx1_bytes=0
prev_tx2_bytes=0

GREEN='\033[0;32m'
NC='\033[0m' # No Color


print_qdisc_bytes() {
    # Get current byte counts
    current_tx1_bytes=$(ip netns exec router tc -s qdisc show dev r_veth | grep -A5 '10:' | grep 'Sent' | head -n 1 | awk '{print $2}')
    current_tx2_bytes=$(ip netns exec router tc -s qdisc show dev r_veth | grep -A5 '20:' | grep 'Sent' | tail -n 1 | awk '{print $2}')

    # Calculate deltas
    delta_tx1=$((current_tx1_bytes - prev_tx1_bytes))
    delta_tx2=$((current_tx2_bytes - prev_tx2_bytes))

    # Print current and delta values
    echo

    printf "${GREEN}%-25s %-10s | %-25s %-10s${NC}\n" "tx ring 1 (10:):" "$current_tx1_bytes bytes" "tx ring 2 (20:):" "$current_tx2_bytes bytes"
    printf "${GREEN}%-25s %+10s | %-25s %+10s${NC}\n" "Delta:" "$delta_tx1 bytes" "Delta:" "$delta_tx2 bytes"

    echo

    # Update previous values
    prev_tx1_bytes=$current_tx1_bytes
    prev_tx2_bytes=$current_tx1_bytes
    echo
}


echo "Initial Qdisc Bytes"

print_qdisc_bytes


echo "Setup iperf3 server on Server 1 (192.168.1.2)"
sudo ip netns exec server1 iperf3 -s &

#IPERF3 TESTING!!!

echo "Run iperf3 client on Client (192.168.0.2), connect with Server 1 (192.168.1.2)"
sudo ip netns exec client iperf3 -c 192.168.1.2 -bidir

# To see how many bytes how gone through each qdisc after ping from client to server 1
print_qdisc_bytes

echo "Setup iperf3 server on Server 2 (192.168.1.3)"
sudo ip netns exec server2 iperf3 -s &

echo "Run iperf3 client on Client (192.168.0.2), connect with Server 2 (192.168.1.3)"
sudo ip netns exec client iperf3 -c 192.168.1.3 -bidir

# To see how many bytes how gone through each qdisc after ping from client to server 2
print_qdisc_bytes

