
import csv
import ast
import argparse
import os

def parse_file(input_file, output_file, packet_size):
    with open(input_file, "r") as f:
        lines = f.readlines()

    # First line -> list of tuples [(seq, send_time), ...]
    send_list = ast.literal_eval(lines[0].strip())
    send_data = dict(send_list)  # keep dict for lookup, list for order

    # Second line -> space-separated "seq,time"
    recv_data = {}
    for pair in lines[1].strip().split():
        seq, t = pair.split(",")
        recv_data[int(seq)] = float(t)

    with open(output_file, "w", newline="") as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow([
            "start", "end", "seconds", "bytes",
            "bits_per_second", "rtt", "omitted", "sender"
        ])

        for i in range(len(send_list) - 1):  # stop before last
            seq, send_time = send_list[i]
            _, next_send_time = send_list[i + 1]

            start = send_time
            end = next_send_time
            delta = end - start

            bits_per_second = ""
            if delta > 0:
                bits_per_second = (packet_size * 8) / delta

            # RTT using recv timestamp if available
            rtt = ""
            if seq in recv_data:
                rtt = (recv_data[seq] - send_time) * 2

            writer.writerow([
                f"{start:.9f}",
                f"{end:.9f}",
                f"{delta:.9f}",
                packet_size,
                f"{bits_per_second:.2f}" if bits_per_second else "",
                f"{rtt:.9f}" if rtt != "" else "",
                "false" if rtt !="" else "true",  # omitted
                "true"    # sender
            ])

def process_file(file_path): 
    filename = os.path.basename(file_path) 
    parse_file(file_path, file_path.replace(".txt", ".csv"),  int(filename.split('-')[2]))

def walk_and_process(root_dir): 
    for dirpath, _, filenames in os.walk(root_dir): 
        parent = os.path.basename(dirpath) 
        if any(tag in parent for tag in ("T1", "T2", "T3")): 
            for filename in filenames: 
                if filename.endswith(".txt"): 
                    file_path = os.path.join(dirpath, filename)
                    process_file(file_path)

if __name__ == "__main__":
    # parser = argparse.ArgumentParser(description="Convert UDP send/receive logs to CSV")
    # parser.add_argument("input_file", help="Path to input text file")
    # parser.add_argument("output_file", help="Path to output CSV file")
    # parser.add_argument("bytes", type=int, help="Packet size in bytes")

    # args = parser.parse_args()
    # parse_file(args.input_file, args.output_file, args.bytes)

    base_dir = "tests"  # top-level directory
    walk_and_process(base_dir)



   
