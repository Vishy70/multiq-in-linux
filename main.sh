#!/bin/bash

# Cli usage function
usage() {
  echo -e "Usage: $0 -n <number of iterations> [-r to reset topology, -h for help] (filename) ([list of qdiscs to run])\n"
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
    ./qdisc-setup.sh "$baseline"
}

# Default number of iterations: 10
# Don't reset topology
# Set filename
n=3
reset=true
filename="$1"
algos=("pie" "fq_codel" "fq_pie")
TEST_DIR="./tests"

# Use getopts to parse optional flags
# n: number of iterations to run
# h: display cli help message
# r: DO NOT reset the topology
# arg1: test name
# vargs: list of qdiscs to test over
while getopts "n:rh" opt; do
    case $opt in
    n)
        n="$OPTARG"
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

# Ignore filename...rest of arguments are qdisc names.
shift

if [ $# -gt 0 ];
then
    algos=("$@");
fi

if [ "$reset" = true ];
then
    echo -e "Resetting topology...\n"
    test_setup true
else
    ./qdisc-setup.sh true
fi

#Run the baseline
for qdisc_algo in "${algos[@]}";
do
    for ((i=1;i<=n;i++)); 
    do
        ./qdisc-change.sh true $qdisc_algo
        ./traffic-test.sh "$TEST_DIR/$filename-baseline-$qdisc_algo-$i"
    done
done

if [ $# -eq 0 ];
then
    exit 0
fi

# qdisc-change, filters.sh called on each qdisc update during test
./qdisc-setup.sh false

./filters.sh
for qdisc_algo_1 in "${algos[@]}";
do
    for qdisc_algo_2 in "${algos[@]}";
    do
        for ((i=1;i<=n;i++));
        do
            ./qdisc-change.sh false "$qdisc_algo_1" "$qdisc_algo_2"
            ./traffic-test.sh "$TEST_DIR/$filename-$qdisc_algo_1-lat_$qdisc_algo_2-tpt-$i"
        done
    done
done

sudo rm -f server-dump.txt 

./rm.sh