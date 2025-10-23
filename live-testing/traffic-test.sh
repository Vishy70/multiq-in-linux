logdir="$1"
LAT_IP="$2"
SAT_IP="$3"
e_time="$4"
i_time="$5"
if [ -z "$2" ];
then
    e_time=30
fi
cooldown=$((e_time / 2))

T1 () {
    client="$1"
    ip="$2"
    bw="$3"
    suffix="$4"
    folder="$5"

    #sudo ip netns exec "$client" ping -c "$e_time" -i 1 "$ip" &> "$logdir/$folder/$client-$bw-$suffix-PING.txt" &
    sudo iperf3 -b 128K -t "$e_time" -i 1 --logfile "$logdir/$folder/$client-$bw-$suffix" -J -u -c "$ip" &
}

T_UDP_RTT () {
    client="$1"
    ip="$2"
    bw_str="$3" 
    suffix="$4"
    folder="$5"
    mss="$6"

    sudo python3 ./udp_rtt_client.py \
        --host "$ip" \
        --duration "$e_time" \
        --bitrate "$bw_str" \
        --size "$mss" \
        --logfile "$logdir/$folder/$client-$bw_str-$mss-$suffix.txt" &

}

T2_3 () {
    client="$1"
    ip="$2"
    bw="$3"
    mss="$4"
    suffix="$5"
    folder="$6"

    sudo ping -c "$e_time" -i 1 "$ip" &> "$logdir/$folder/$client-$bw-$mss-$suffix-PING.txt" &
    sudo iperf3 -b "$bw" -t "$e_time" -l "$mss" -i 1 --logfile "$logdir/$folder/$client-$bw-$mss-$suffix" -J -u -c "$ip" &
}

T4 () {
    # tcp!
    client="$1"
    ip="$2"
    suffix="$3"
    folder="$4"

    sudo iperf3 -b 30M -t "$e_time" -i 1 --logfile "$logdir/$folder/$client-30M-$suffix" -J -c "$ip" &
}

T5 () {
    client="$1"
    ip="$2"
    suffix="$3"
    folder="$4"

    sudo iperf3 -t "$e_time" -C cubic -i 1 --logfile "$logdir/$folder/$client-tcp-sat-$suffix" -J -c "$ip" &
}

T6 () {
    client="$1"
    ip="$2"
    suffix="$3"
    folder="$4"

    sudo ./qperf.out -t "$e_time" --cc cubic -c "$ip" &> "$logdir/$folder/$client-quic-sat-$suffix" &
}

echo "Setup iperf3 server on Server 1 ($LAT_IP)"
sudo iperf3 -s &> "server-dump.txt" &

sudo python3 ./udp_rtt_server.py --logfile "rtt-server-dump.txt" --host "$LAT_IP" &


#echo "Setup iperf3 server on Server 2 (192.168.0.3)"
sudo iperf3 -s &> "server-dump.txt" &

echo "Setup qperf server on Server 2 ($SAT_IP)"
sudo ./qperf.out --cc cubic -s "$SAT_IP" &> "server-dump.txt" &

#IPERF3 & QPERF TESTING!!!
sat_traffic_classes=(T5 T6)

# Class 1 x Class 3 class1=(T1 T2_3 T2_3)
for sat_traffic in "${sat_traffic_classes[@]}"; 
do

    echo "Running T1-$sat_traffic"
    folder="T1-$sat_traffic"
    mkdir -p $logdir/$folder
    # T1 "client1" "192.168.0.2" "128K" "$sat_traffic" "$folder"
    T_UDP_RTT "client1" "$LAT_IP" "128000" "$sat_traffic" "$folder" "1460"
    $sat_traffic "client2" "$SAT_IP" "128k" "$folder"
    sleep $(($e_time + $cooldown))
    cat "rtt-server-dump.txt" >> "$logdir/$folder/client1-128000-1460-$sat_traffic.txt"
    > rtt-server-dump.txt

    echo "Running T2-$sat_traffic"
    folder="T2-$sat_traffic"
    mkdir -p $logdir/$folder
    # T2_3 "client1" "192.168.0.2" "70K" "150" "$sat_traffic" "$folder"
    T_UDP_RTT "client1" "$LAT_IP" "70000" "$sat_traffic" "$folder" "150"
    $sat_traffic "client2" "$SAT_IP" "70K-150" "$folder"
    sleep $(($e_time + $cooldown))
    cat "rtt-server-dump.txt" >> "$logdir/$folder/client1-70000-150-$sat_traffic.txt"
    > rtt-server-dump.txt

    echo "Running T3-$sat_traffic"
    folder="T3-$sat_traffic"
    mkdir -p $logdir/$folder
    # T2_3 "client1" "192.168.0.2" "1.5M" "900" "$sat_traffic" "$folder"
    T_UDP_RTT "client1" "$LAT_IP" "1500000" "$sat_traffic" "$folder" "900"
    $sat_traffic "client2" "$SAT_IP" "1.5M-900" "$folder"
    sleep $(($e_time + $cooldown))
    cat "rtt-server-dump.txt" >> "$logdir/$folder/client1-1500000-900-$sat_traffic.txt"
    > rtt-server-dump.txt

done

# Class 2 X Class 3
for sat_traffic in "${sat_traffic_classes[@]}"; 
do

    echo "Running T4-$sat_traffic"
    folder="T4-$sat_traffic"
    mkdir -p $logdir/$folder
    T4 "client1" "$LAT_IP" "$sat_traffic" "$folder"
    $sat_traffic "client2" "$SAT_IP" "30M" "$folder"
    sleep $(($e_time + $cooldown))

done

sudo pkill iperf3
sudo pkill ./qperf.out
sudo pkill ./udp_rtt_server.py

exit 0
