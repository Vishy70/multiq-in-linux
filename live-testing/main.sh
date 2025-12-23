#!/bin/bash

# Cli usage function
usage() {
  echo -e "Usage: $0 -n <num iterations> -l <lat-server's-ip> -s <saturating-server's-ip> [-r to reset topology, -h for help] (filename) ([list of qdiscs to run])\n"
}

test_setup() {
    baseline="$1"

    # Remove topology setup
    ./rm.sh
    # TODO: Error handle any issues with removal
    ./rm.sh
    # Setup topology again
    ./setup.sh
    # Only setup up multiq, pfifo for baseline
    ./qdisc-setup.sh "$baseline" "$DEV_NAME" ""
}

# Default number of iterations: 10
# Don't reset topology
# Set filename
n=3
reset=true
filename="$1"
baseline_algos=("pfifo" "dualpi2" "fq_codel" "fq_pie")
algos=("pfifo" "fq_codel" "fq_pie")
TEST_DIR="./tests"
LAT_IP=""
SAT_IP=""
DEV_NAME=""
SERIAL_NUM=""

# Use getopts to parse optional flags
# n: number of iterations to run
# h: display cli help message
# r: DO NOT reset the topology
# arg1: test name
# vargs: list of qdiscs to test over
while getopts "n:l:s:rh" opt; do
    case $opt in
    n)
        n="$OPTARG"
        ;;
    l)
        LAT_IP="$OPTARG"
        ;;
    s)
        SAT_IP="$OPTARG"
        ;;
    r)
        reset="false"
        ;;
    h)
        usage
        exit 0
        ;;
    \?)
  	    echo "Invalid option: -$OPTARG"
        usage
        exit 1
  	    ;;
	:)
  	    echo "Option -$OPTARG requires an argument."
  	    usage
        exit 1
        ;;
    esac
done

shift $((OPTIND - 1))

if [ ! -d $TEST_DIR ];
then
    mkdir $TEST_DIR
fi

# Verify filename exists
if [ -z "$1" ];
then
    echo "Error: Filename is required."
    usage
    exit 1
fi

# if [ -z "$LAT_IP" ];
# then
#     echo "Error: Please provide the Latency Traffic Server's IP Address."
#     usage
#     exit 1
# fi

# if [ -z "$SAT_IP" ];
# then
#     echo "Error: Please provide the Saturating Traffic Server's IP Address."
#     usage
#     exit 1
# fi

# Ignore filename...rest of arguments are qdisc names.
shift

# if [ $# -gt 0 ];
# then
#     algos=("$@");
# fi

./qdisc-setup.sh true $DEV_NAME $SERIAL_NUM

#Run the baseline
for qdisc_algo in "${baseline_algos[@]}";
do
    for ((i=1;i<=n;i++)); 
    do
        ./qdisc-change.sh true $DEV_NAME $SERIAL_NUM $qdisc_algo 
        ./traffic-test.sh "$TEST_DIR/$filename-baseline-$qdisc_algo-$i" "$LAT_IP" "$SAT_IP"
    done
done

if [ $# -eq 0 ];
then
    exit 0
fi

# qdisc-change, filters.sh called on each qdisc update during test
./qdisc-setup.sh false $DEV_NAME $SERIAL_NUM

./filters.sh $LAT_IP $DEV_NAME $SERIAL_NUM
for qdisc_algo_1 in "${algos[@]}";
do
    for qdisc_algo_2 in "${algos[@]}";
    do
        for ((i=1;i<=n;i++));
        do
            ./qdisc-change.sh false $DEV_NAME $SERIAL_NUM "$qdisc_algo_1" "$qdisc_algo_2"
            ./traffic-test.sh "$TEST_DIR/$filename-$qdisc_algo_1-lat_$qdisc_algo_2-tpt-$i" "$LAT_IP" "$SAT_IP" 
        done
    done
done

sudo rm -f server-dump.txt 

./rm.sh