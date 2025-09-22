import pandas as pd
import sys
import os
import json
import csv
import re

def main():
    if len(sys.argv) != 3:
        print(len(sys.argv))
        print("Usage: python script.py <filename-ping.txt>")
        return

    src_name = sys.argv[1]
    dest_name = sys.argv[2]
    ping_file = src_name
    
    src_name = src_name.replace(".txt", "")
    src_name = src_name.replace("-PING", "")
    dest_name = dest_name.replace(".txt", "")
    dest_name = dest_name.replace("-PING", "")

    # regex for extracting time field
    time_regex = re.compile(r'icmp_seq=(\d+).*time=([\d.]+)')

    rtts = []
    with open(ping_file, "r") as f:
        for line in f:
            match = time_regex.search(line)
            if match:
                icmp_seq = int(match.group(1))
                rtt = float(match.group(2))
                rtts.append((icmp_seq, rtt))

    
    dest_df = pd.read_csv(dest_name)
    dest_df['rtt'] = pd.to_numeric(dest_df['rtt'], errors='coerce').astype('float64')

    for icmp_seq, rtt_value in rtts:
        target_mask = dest_df['start'] >= int(icmp_seq)
        
        if target_mask.any():
            target_index = target_mask.idxmax()
            
            # Insert the RTT value at that specific index
            dest_df.loc[target_index, 'rtt'] = rtt_value
            
    
    dest_df.to_csv(dest_name, index=False)

if __name__ == "__main__":
    main()
