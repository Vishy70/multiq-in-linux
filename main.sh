#!/bin/bash

# cli usage function
usage() {
  echo -e "Usage: $0 
  -a <[list of algorithms to run hybrid qdisc tests]>
  -b <[list of algorithms to run baseline qdisc tests]>
  -d <device name to configure qdisc>
  -n <num iterations>
  -s <serial number of device to connect via adb>
  -r <reset the virtual topology after completion: include the flag to set>
  -t <test type: flent|six-traffic-class>
  -v <whether to use virtual testbed or not: include the flag to set>
  -L <lat-server's-ip>
  -S <saturating-server's-ip>
  (filename)"
}

test_setup() {
    local baseline="$1"

    # NOTE: fixed missing space before ]] (was a syntax error: "true]")
    if [[ "$virtual" = true ]];
    then
        # Remove topology setup
        ./rm.sh
        ./rm.sh
        # Setup topology again
        ./setup.sh
    fi
    # Only setup up multiq, pfifo for baseline
    # TODO: Change this to mq
    ./qdisc-setup.sh "$virtual" "$baseline" "$DEV_NAME" "$SERIAL_NUM"
}

# configurable parameters of the script
algos=("pfifo" "fq_pie" "fq_codel")
baseline_algos=("pfifo" "fq_pie" "fq_codel")
DEV_NAME=""
SERIAL_NUM=""
n=3
reset=true
test_name=""
virtual="false"
LAT_IP=""
SAT_IP=""
filename="qdisc-test"
TEST_DIR="./tests"

positional_args=() # For normal arguments without flags
# guardrail function while parsing args
require_arg() {
    local flag="$1"
    local arg="$2"
    if [[ -z "$arg" || "$arg" =~ ^- ]]; then
        echo "Error: The $flag flag requires a valid argument."
        exit 1
    fi
}

# Arg parse loop
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -a)
            require_arg $1 $2
            shift
            algos=()
            while [[ "$#" -gt 0 && ! "$1" =~ ^- ]]; do
                algos+=("$1")
                shift
            done
            ;;
        -b)
            require_arg $1 $2
            shift
            baseline_algos=()
            while [[ "$#" -gt 0 && ! "$1" =~ ^- ]]; do
                baseline_algos+=("$1")
                shift
            done
            ;;
        -d)
            require_arg $1 $2
            DEV_NAME=$2
            shift 2
            ;;
        -n) 
            require_arg $1 $2
            n=$2
            shift 2
            ;;
        -s)
            require_arg $1 $2
            SERIAL_NUM=$2
            shift 2
            ;;
        -r)
            reset="true"
            shift
            ;;
        -t)
            require_arg $1 $2
            test_name=$2
            shift 2
            ;;
        -v)
            virtual="true"
            shift
            ;;
        -L) 
            require_arg $1 $2
            LAT_IP=$2
            shift 2
            ;;
        -S)
            require_arg $1 $2
            SAT_IP=$2
            shift 2
            ;;
        -h)
            usage
            exit 0
            ;;
        -*)
            echo "Error: Unknown flag passed: $1"
            usage
            exit 1
            ;;
        *)
            # standard positional arguments
            positional_args+=("$1")
            shift
            ;;
    esac
done

filename=${positional_args[0]}

# null / does not exist checks
if [ ! -d $TEST_DIR ];
then
    mkdir $TEST_DIR
fi

if [ -z "$filename" ];
then
    echo "Error: Filename is required."
    usage
    exit 1
fi

if [[ "$test_name" = "six-traffic-class" && -z "$LAT_IP" ]];
then
    echo "Error: Please provide the Latency Traffic Server's IP Address."
    usage
    exit 1
fi

if [[ "$test_name" = "six-traffic-class" && -z "$SAT_IP" ]];
then
    echo "Error: Please provide the Saturating Traffic Server's IP Address."
    usage
    exit 1
fi

# ------------------------------------------------------------------
# Resume support: a checkpoint file records "<qdisc>:<iter>:DONE"
# lines once an iteration's full set of sub-tests has been validated
# (see flent-test.sh). If main.sh is re-run after a connection
# failure, already-completed (qdisc, iteration) pairs are skipped
# entirely, and flent-test.sh itself resumes any partially-completed
# iteration at the sub-test level.
# ------------------------------------------------------------------
CHECKPOINT_FILE="${TEST_DIR}/.checkpoint"
touch "$CHECKPOINT_FILE"

is_done() {
    grep -Fxq "$1" "$CHECKPOINT_FILE"
}

# Setup the real / virtual topology, qdiscs
test_setup true

#Run the baseline
for qdisc_algo in "${baseline_algos[@]}";
do
    for ((i=1;i<=n;i++)); 
    do
        if is_done "${qdisc_algo}:${i}:DONE"; then
            echo "Skipping already-completed iteration: $qdisc_algo (iter $i)"
            continue
        fi

        ./qdisc-change.sh $virtual true $qdisc_algo "" $DEV_NAME $SERIAL_NUM 
        case "$test_name" in
        flent)
            ./flent-test.sh "$qdisc_algo" "$i" "${TEST_DIR}/${qdisc_algo}"
            flent_status=$?
            if [[ $flent_status -ne 0 ]]; then
                echo "Error: flent test failed for qdisc=$qdisc_algo iteration=$i."
                echo "Progress so far is saved in $CHECKPOINT_FILE."
                echo "Fix the connection issue and re-run this script with the same arguments to resume."
                exit 1
            fi
        ;;
        six-traffic-class)
            #./traffic-test.sh "$TEST_DIR/$filename-baseline-$qdisc_algo-$i" "$LAT_IP" "$SAT_IP"
            echo "Skipped"
        ;;
        *)
            echo "No supported test for baseline for test named: $testname."
        esac        
    done
done

# qdisc-change, filters applied for hybrid qdisc setup
# ./qdisc-setup.sh "$virtual" "false" "$DEV_NAME" "$SERIAL_NUM"

# for qdisc_algo_1 in "${algos[@]}";
# do
#     for qdisc_algo_2 in "${algos[@]}";
#     do
#         for ((i=1;i<=n;i++));
#         do
#             ./qdisc-change.sh $virtual false "$qdisc_algo_1" "$qdisc_algo_2" $DEV_NAME $SERIAL_NUM
#             ./filters.sh "$virtual" "$LAT_IP" "$DEV_NAME" "$SERIAL_NUM"

#             case "$test_name" in
#             six-traffic-class)
#                 #./traffic-test.sh "$TEST_DIR/$filename-$qdisc_algo_1-lat_$qdisc_algo_2-tpt-$i" "$LAT_IP" "$SAT_IP"
#                 echo "Skipped"
#             ;;
#             *)
#                 echo "No supported test for hybrid qdisc for test named: $testname."
#             esac
#         done
#     done
# done

sudo rm -f server-dump.txt

if [[ "$virtual" = true && "$reset" = true ]];
then
    #./rm.sh
    echo "Skipped"
fi
