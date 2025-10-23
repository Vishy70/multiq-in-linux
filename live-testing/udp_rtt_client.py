# Save this file as udp_rtt_client.py
import socket
import time
import argparse
import statistics

parser = argparse.ArgumentParser(description="UDP Client for RTT measurement")
parser.add_argument("--host", type=str, required=True, help="Server IP address")
parser.add_argument("--port", type=int, default=12345, help="Server port (default: 12345)")
parser.add_argument("--duration", type=int, default=15, help="Test duration in seconds")
parser.add_argument("--size", type=int, default=56, help="Packet payload size in bytes")
parser.add_argument("--logfile", type=str, required=True, help="File to save summary statistics")
parser.add_argument("--bitrate", type=int, help="Target bitrate in bits per second")
args = parser.parse_args()

SERVER_IP = args.host
SERVER_PORT = args.port
DURATION = args.duration
BITRATE = args.bitrate
PACKET_SIZE = args.size
LOGFILE = args.logfile


if args.bitrate:
    INTERVAL = (PACKET_SIZE * 8) / args.bitrate
else:
    INTERVAL = 1

packets_sent = 0
packets_received = 0
sequence_number = 0

client_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
client_socket.settimeout(max(0.1, INTERVAL * 0.95))

print(f"Sending {SERVER_IP}:{SERVER_PORT} with {PACKET_SIZE}-byte packets for {DURATION} seconds.")

start_time = time.monotonic()

sent_packets = [] 
while (time.monotonic() - start_time) < DURATION:
    sequence_number += 1
    send_time = time.monotonic()
    sent_packets.append((sequence_number, send_time))
    # Payload format: "sequence_number,send_timestamp"
    # We pad the message to meet the desired packet size.
    payload = f"{sequence_number}".encode('utf-8')
    padding_size = PACKET_SIZE - len(payload)
    if padding_size < 0:
        print("Error: PACKET_SIZE too small for timestamp.")
        break
    payload = payload + (b',')
    padding_size-=1
    message = payload + (b'A' * padding_size)
    client_socket.sendto(message, (SERVER_IP, SERVER_PORT))

    # Wait for the next interval
    time.sleep(max(0, INTERVAL - (time.monotonic() - send_time)))

client_socket.close()

# --- Summary ---
# print("\n--- UDP RTT Statistics ---")
# loss_percentage = ((packets_sent - packets_received) / packets_sent * 100) if packets_sent > 0 else 0

# summary = f"Packets: Sent = {packets_sent}, Received = {packets_received}, Lost = {packets_sent - packets_received} ({loss_percentage:.2f}% loss)\n"

# if rtt_list:
#     min_rtt = min(rtt_list)
#     max_rtt = max(rtt_list)
#     avg_rtt = statistics.mean(rtt_list)
#     stddev_rtt = statistics.stdev(rtt_list) if len(rtt_list) > 1 else 0
#     summary += f"Minimum = {min_rtt:.3f}ms, Maximum = {max_rtt:.3f}ms, Average = {avg_rtt:.3f}ms, StdDev = {stddev_rtt:.3f}ms\n"
# else:
#     summary += "No packets were received.\n"

# print(summary)

# Write summary to logfile
with open(LOGFILE, 'a') as f:
    f.write(str(sent_packets)+"\n")
