## How to run

- switch to root user (sudo su)
- chmod +x [./main.sh](./main.sh)
- [./main.sh](./main.sh)

## Tests available
- [testing.sh](./testing.sh) : Ping tests to manually see where the packets are going!
- [rate_limiting.sh](./rate_limiting.sh) : IPERF3 testing, using tbf qdisc to shape iperf3 traffic in priority queue!

    Please note: YOU MUST change a couple of lines in [qdisc.sh](./qdisc.sh) to use [testing.sh](./testing.sh) or [rate_limiting.sh](./rate_limiting.sh)


    Topology:

    Client -> Router -> Switch -> 1. Server1 2. Server2