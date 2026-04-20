
sudo apt update
sudo apt install git cmake libssl-dev libev-dev g++ flent fping netperf -y

openssl req -x509 -newkey rsa:4096 -keyout server.key -out server.crt -sha256 -days 365 -nodes -subj "/C=US/ST=Oregon/L=Portland/O=Company Name/OU=Org/CN=www.example.com"
# qperf fork with some experimental extra logs 
git clone --recurse-submodules https://github.com/vishy0777/qperf

mkdir build-qperf
cd build-qperf
cmake ../qperf
make

mv qperf ../qperf.out
cd ..
rm -rf qperf/ build-qperf/
chmod +x *.sh
chmod +x ./qperf.out