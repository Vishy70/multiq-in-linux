
import csv
import ast
import argparse
import os

def parse_file(input_file, output_file, packet_size):
    with open(input_file, "r") as f:
        # Read the list of (send_time, recv_time) tuples
        data = sorted(ast.literal_eval(f.read().strip()), key=lambda x: x[0])

    with open(output_file, "w", newline="") as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow([
            "start", "end", "seconds", "bytes",
            "bits_per_second", "rtt_ms", "omitted", "sender"
        ])

        for i in range(len(data) - 1):
            send_time, recv_time = data[i]
            next_send_time, _ = data[i + 1]

            start = send_time
            end = recv_time
            seconds = recv_time - send_time
            delta = next_send_time - send_time  # time gap between consecutive sends

            bits_per_second = ""
            if delta > 0:
                bits_per_second = (packet_size * 8) / delta

            rtt_ms = seconds * 1000  # convert to milliseconds

            writer.writerow([
                f"{start:.9f}",
                f"{end:.9f}",
                f"{seconds:.9f}",
                packet_size,
                f"{bits_per_second:.2f}" if bits_per_second else "",
                f"{rtt_ms:.9f}",
                "false",  # not omitted
                "true"    # sender
            ])

def process_file(file_path): 
    filename = os.path.basename(file_path) 
    parse_file(file_path, file_path.replace(".txt", ".csv").replace("tests","tests-csv"),  int(filename.split('-')[2]))

def walk_and_process(root_dir): 
    for dirpath, _, filenames in os.walk(root_dir): 
        parent = os.path.basename(dirpath) 
        if any(tag in parent for tag in ("T1", "T2", "T3")): 
            for filename in filenames: 
                if filename.endswith(".txt"): 
                    file_path = os.path.join(dirpath, filename)
                    print(file_path)
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



   
