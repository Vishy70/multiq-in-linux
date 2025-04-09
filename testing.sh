
# Initialize previous byte counts
prev_pie_bytes=0
prev_codel_bytes=0

GREEN='\033[0;32m'
NC='\033[0m' # No Color


print_qdisc_bytes() {
    # Get current byte counts
    current_pie_bytes=$(ip netns exec router tc -s qdisc show dev r_veth | grep -A5 '10:' | grep 'Sent' | awk '{print $2}')
    current_codel_bytes=$(ip netns exec router tc -s qdisc show dev r_veth | grep -A5 '20:' | grep 'Sent' | awk '{print $2}')

    # Calculate deltas
    delta_pie=$((current_pie_bytes - prev_pie_bytes))
    delta_codel=$((current_codel_bytes - prev_codel_bytes))

    # Print current and delta values
    echo



    printf "${GREEN}%-25s %-10s | %-25s %-10s${NC}\n" "fq_pie (10:):" "$current_pie_bytes bytes" "fq_codel (20:):" "$current_codel_bytes bytes"
    printf "${GREEN}%-25s %+10s | %-25s %+10s${NC}\n" "Delta:" "$delta_pie bytes" "Delta:" "$delta_codel bytes"


    echo

    # Update previous values
    prev_pie_bytes=$current_pie_bytes
    prev_codel_bytes=$current_codel_bytes
    echo
}




echo "Initial Qdisc Bytes"

print_qdisc_bytes

echo "Pinging Packets from Client (192.168.0.2/24) to Server 1 (192.168.1.2/24)"
sudo ip netns exec client ping -s 5000 -c 5 192.168.1.2

# To see how many bytes how gone through each qdisc after ping from client to server 1
print_qdisc_bytes

echo "Pinging Packets from Client (192.168.0.2/24) to Server 2 (192.168.1.3/24)"
sudo ip netns exec client ping -s 5000 -c 5 192.168.1.3


# To see how many bytes how gone through each qdisc after ping from client to server 2
print_qdisc_bytes


sudo ip netns exec router tc -s qdisc show dev r_veth

