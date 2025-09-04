logdir="$1"
e_time=30
cooldown=$e_time

T1 () {
    client="$1"
    ip="$2"
    bw="$3"
    suffix="$4"
    folder="$5"

    sudo ip netns exec "$client" iperf3 -b 128K -t "$e_time" -i 1 --logfile "$logdir/$folder/$client-$bw-$suffix" -J -u -c "$ip" &
}

T2_3 () {
    client="$1"
    ip="$2"
    bw="$3"
    mss="$4"
    suffix="$5"
    folder="$6"

    sudo ip netns exec "$client" iperf3 -b "$bw" -t "$e_time" -M "$mss" -i 1 --logfile "$logdir/$folder/$client-$bw-$mss-$suffix" -J -u -c "$ip" &
}

T4 () {
    # tcp!
    client="$1"
    ip="$2"
    suffix="$3"
    folder="$4"

    sudo ip netns exec "$client" iperf3 -b 30M -t "$e_time" -i 1 --logfile "$logdir/$folder/$client-30M-$suffix" -J -c "$ip" &
}

T5 () {
    client="$1"
    ip="$2"
    suffix="$3"
    folder="$4"

    sudo ip netns exec "$client" iperf3 -t "$e_time" -C cubic -i 1 --logfile "$logdir/$folder/$client-tcp-sat-$suffix" -J -c "$ip" &
}

T6 () {
    client="$1"
    ip="$2"
    suffix="$3"
    folder="$4"

    sudo ip netns exec "$client" ./qperf.out -t "$e_time" --cc cubic -c "$ip" &> "$logdir/$folder/$client-quic-sat-$suffix" &
}

echo "Setup iperf3 server on Server 1 (192.168.0.2)"
# -i 1 --logfile "$logfile-server-1"
sudo ip netns exec server1 iperf3 -s &> "server-dump.txt" &

#echo "Setup qperf server on Server 1 (192.168.0.2)"
#sudo ip netns exec server1 ./qperf.out --cc cubic -s &

#echo "Setup iperf3 server on Server 2 (192.168.0.3)"
# -i 1 --logfile "$logfile-server-2"
sudo ip netns exec server2 iperf3 -s &> "server-dump.txt" &

echo "Setup qperf server on Server 2 (192.168.0.3)"
sudo ip netns exec server2 ./qperf.out --cc cubic -s "192.168.0.3" &> "server-dump.txt" &

#IPERF3 & QPERF TESTING!!!
sat_traffic_classes=(T5 T6)

# Class 1 x Class 3 class1=(T1 T2_3 T2_3)
for sat_traffic in "${sat_traffic_classes[@]}"; 
do

    echo "Running T1-$sat_traffic"
    folder="T1-$sat_traffic"
    mkdir -p $logdir/$folder
    T1 "client1" "192.168.0.2" "128K" "$sat_traffic" "$folder"
    $sat_traffic "client2" "192.168.0.3" "128k" "$folder"
    sleep $(($e_time + $cooldown))

    echo "Running T2-$sat_traffic"
    folder="T2-$sat_traffic"
    mkdir -p $logdir/$folder
    T2_3 "client1" "192.168.0.2" "70K" "150" "$sat_traffic" "$folder"
    $sat_traffic "client2" "192.168.0.3" "70K-150" "$folder"
    sleep $(($e_time + $cooldown))

    echo "Running T3-$sat_traffic"
    folder="T3-$sat_traffic"
    mkdir -p $logdir/$folder
    T2_3 "client1" "192.168.0.2" "1.5M" "900" "$sat_traffic" "$folder"
    $sat_traffic "client2" "192.168.0.3" "1.5M-900" "$folder"
    sleep $(($e_time + $cooldown))

done

# Class 2 X Class 3
for sat_traffic in "${sat_traffic_classes[@]}"; 
do

    echo "Running T4-$sat_traffic"
    folder="T4-$sat_traffic"
    mkdir -p $logdir/$folder
    T4 "client1" "192.168.0.2" "$sat_traffic" "$folder"
    $sat_traffic "client2" "192.168.0.3" "30M" "$folder"
    sleep $(($e_time + $cooldown))

done

sudo ip netns exec server1 pkill iperf3
sudo ip netns exec server2 pkill ./qperf.out

exit 0
