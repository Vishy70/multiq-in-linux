#!/bin/bash

clear
chmod +x rm.sh setup.sh qdisc.sh filters.sh testing.sh
./rm.sh
./setup.sh
./qdisc.sh
./filters.sh
./testing.sh