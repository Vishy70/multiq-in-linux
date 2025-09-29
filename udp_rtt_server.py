# Save this file as udp_rtt_server.py
import socket
import argparse
import time
# --- Argument Parser ---
parser = argparse.ArgumentParser(description="UDP Echo Server for RTT measurement")
parser.add_argument("--host", type=str, default="0.0.0.0", help="Host IP to bind to (default: 0.0.0.0)")
parser.add_argument("--logfile", type=str, required=True, help="File to save summary statistics")
parser.add_argument("--port", type=int, default=12345, help="Port to listen on (default: 12345)")
args = parser.parse_args()

# --- Server Setup ---
HOST = args.host
PORT = args.port
BUFFER_SIZE = 2048 # Should be larger than the max packet size from client

rcv_packets = []
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as server_socket:
    server_socket.bind((HOST, PORT))
    try:
        while True:
            message, address = server_socket.recvfrom(BUFFER_SIZE)
            decoded = message.decode('utf-8')
            parts = decoded.split(',')
            with open(args.logfile, 'a') as f:
                f.write(f"{parts[0]},{time.monotonic()} ")
    except KeyboardInterrupt:
        print("Server shutting down.")





