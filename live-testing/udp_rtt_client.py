# udp_rtt_client.py
import socket
import time
import argparse
import threading
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

if BITRATE:
    INTERVAL = (PACKET_SIZE * 8) / BITRATE
else:
    INTERVAL = 1  

client_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

print(f"Sending to {SERVER_IP}:{SERVER_PORT} with {PACKET_SIZE}-byte packets for {DURATION} seconds.")

sent_packets = {}       
rtts = []               
lock = threading.Lock()
stop_event = threading.Event()
display_list = []

def receiver_thread():
    """Continuously receive responses from the server and compute RTTs."""
    while not stop_event.is_set():
        try:
            data, addr = client_socket.recvfrom(2048)
            recv_time = time.monotonic()

            seq_str = data.split(b',')[0]
            seq_num = int(seq_str)

            with lock:
                if seq_num in sent_packets:
                    send_time = sent_packets.pop(seq_num)
                    rtt = (recv_time - send_time) * 1000
                    display_list.append((send_time, recv_time))  
                    rtts.append(rtt)

        except socket.timeout:
            continue
        except Exception as e:
            print(f"[Receiver] Error: {e}")
            break

# Start receiver thread
recv_thread = threading.Thread(target=receiver_thread, daemon=True)
recv_thread.start()

sequence_number = 0
start_time = time.monotonic()

while (time.monotonic() - start_time) < DURATION:
    sequence_number += 1
    send_time = time.monotonic()

    # Prepare payload
    payload = f"{sequence_number},".encode('utf-8')
    padding_size = PACKET_SIZE - len(payload)
    if padding_size < 0:
        print("Error: PACKET_SIZE too small for payload.")
        break

    message = payload + (b'A' * padding_size)
    with lock:
        sent_packets[sequence_number] = send_time

    client_socket.sendto(message, (SERVER_IP, SERVER_PORT))
    time.sleep(max(0, INTERVAL - (time.monotonic() - send_time)))

# Cleanup
stop_event.set()
recv_thread.join(timeout=1.0)
client_socket.close()

# Compute stats
if rtts:
    avg_rtt = statistics.mean(rtts)
    min_rtt = min(rtts)
    max_rtt = max(rtts)
    stddev = statistics.stdev(rtts) if len(rtts) > 1 else 0.0
else:
    avg_rtt = min_rtt = max_rtt = stddev = 0.0

summary = (
    {f"Packets sent: {sequence_number}\n"
    f"Packets received: {len(rtts)}\n"
    f"Average RTT: {avg_rtt:.3f} ms\n"
    f"Min RTT: {min_rtt:.3f} ms\n"
    f"Max RTT: {max_rtt:.3f} ms\n"
    f"Stddev: {stddev:.3f} ms\n"
    f"{'-'*40}\n"}
)

with open(LOGFILE, 'w') as f:
    f.write(str(display_list) + '\n')
