
sudo apt update
sudo apt install git cmake libssl-dev libev-dev g++ -y

openssl req -x509 -newkey rsa:4096 -keyout server.key -out server.crt -sha256 -days 365 -nodes -subj "/C=US/ST=Oregon/L=Portland/O=Company Name/OU=Org/CN=www.example.com"
git clone --recurse-submodules https://github.com/rbruenig/qperf.git

mkdir build-qperf
cd build-qperf
cmake ../qperf
make

mv qperf ../qperf.out
cd ..
chmod +x *.sh