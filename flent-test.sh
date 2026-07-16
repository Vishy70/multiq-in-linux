#!/bin/bash

# ------------------------------------------------------------------
# flent-test.sh
# Runs the rrul test + 6 tcp_ndown tests for a given qdisc/iteration.
#
# Resumability:
#   Each individual sub-test (rrul, tcp_10down, tcp_25down, ...) is
#   checkpointed in "<TEST_DIR>/.checkpoint" only after its CSV output
#   has been validated. If this script (or the connection) dies
#   partway through, re-running it will skip every sub-test that
#   already succeeded and retry only what's left.
# ------------------------------------------------------------------

qdisc="$1"
echo -e "Using qdisc: $qdisc\n"

iter="$2"
output_dir="$3"

NETSERVER_ADDRESS="netperf-west.bufferbloat.net"
TEST_LENGTH=300
MAX_RETRIES=3
RETRY_DELAY=10  # seconds between retries

# TEST_DIR is the parent of output_dir (e.g. ./tests), checkpoint lives there
TEST_DIR_ROOT="$(dirname "$output_dir")"
CHECKPOINT_FILE="${TEST_DIR_ROOT}/.checkpoint"
mkdir -p "$TEST_DIR_ROOT"
touch "$CHECKPOINT_FILE"

is_done() {
    # Exact line match against the checkpoint file
    grep -Fxq "$1" "$CHECKPOINT_FILE"
}

mark_done() {
    echo "$1" >> "$CHECKPOINT_FILE"
}

# A CSV is only considered valid if it exists, is non-empty, and has
# at least a header row + one data row. This is what stops a
# connection-drop mid-transfer from leaving a corrupt/empty CSV that
# would silently poison MergeCsv.py / PlotGraphs.py downstream.
validate_csv() {
    local file="$1"
    [[ -s "$file" ]] || return 1
    local lines
    lines=$(wc -l < "$file")
    [[ "$lines" -ge 2 ]] || return 1
    return 0
}

# run_flent_test <checkpoint_key> <expected_output_csv> <command...>
run_flent_test() {
    local key="$1"; shift
    local out_file="$1"; shift

    if is_done "$key"; then
        echo "Skipping already-completed test: $key"
        return 0
    fi

    local attempt=1
    while (( attempt <= MAX_RETRIES )); do
        echo "Running: $key (attempt $attempt/$MAX_RETRIES)"
        "$@"
        local status=$?

        if [[ $status -eq 0 ]] && validate_csv "$out_file"; then
            mark_done "$key"
            echo "Completed: $key"
            return 0
        fi

        echo "Failed or invalid CSV for $key (exit=$status). Removing partial file and retrying..."
        rm -f "$out_file"
        attempt=$((attempt + 1))
        [[ $attempt -le $MAX_RETRIES ]] && sleep "$RETRY_DELAY"
    done

    echo "ERROR: $key failed after $MAX_RETRIES attempts."
    return 1
}

# ---------------- RRUL TEST ----------------
RRUL_DIR="$output_dir/rrul"
mkdir -p "$RRUL_DIR"
RRUL_TEST_NAME="rrul_${qdisc}_${TEST_LENGTH}"
RRUL_OUT="${RRUL_DIR}/${iter}-${RRUL_TEST_NAME}.csv"
RRUL_KEY="${qdisc}:${iter}:rrul"

echo -e "Running rrul test with qdisc=$qdisc...\n"
run_flent_test "$RRUL_KEY" "$RRUL_OUT" \
    flent rrul -H "$NETSERVER_ADDRESS" --length="$TEST_LENGTH" -f csv --output="$RRUL_OUT"
if [[ $? -ne 0 ]]; then
    echo "Aborting flent-test.sh for qdisc=$qdisc iter=$iter (rrul stage failed). Re-run to resume."
    exit 1
fi

# ---------------- TCP_NDOWN TESTS ----------------
DOWNLOAD_STREAMS=(10 25 50 75 100 200)

for n in "${DOWNLOAD_STREAMS[@]}"; do
    TCP_NDOWN_DIR="$output_dir/tcp_${n}down"
    mkdir -p "$TCP_NDOWN_DIR"
    TCP_NDOWN_TEST_NAME="tcp_${n}down_${qdisc}_${TEST_LENGTH}"
    TCP_OUT="${TCP_NDOWN_DIR}/${iter}-${TCP_NDOWN_TEST_NAME}.csv"
    TCP_KEY="${qdisc}:${iter}:tcp_${n}down"

    echo -e "\nRunning tcp_ndown test with n=$n, qdisc=$qdisc...\n"
    run_flent_test "$TCP_KEY" "$TCP_OUT" \
        flent tcp_ndown --test-parameter=download_streams="$n" -H "$NETSERVER_ADDRESS" --length="$TEST_LENGTH" -f csv --output="$TCP_OUT"
    if [[ $? -ne 0 ]]; then
        echo "Aborting flent-test.sh for qdisc=$qdisc iter=$iter (tcp_${n}down stage failed). Re-run to resume."
        exit 1
    fi
done

# Only mark the whole iteration DONE once every sub-test succeeded
mark_done "${qdisc}:${iter}:DONE"
exit 0
