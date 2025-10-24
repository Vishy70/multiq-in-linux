import socket

server_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
server_socket.bind(("192.168.1.2", 12345))

while True:
    data, addr = server_socket.recvfrom(2048)
    server_socket.sendto(data, addr)
