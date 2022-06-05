#!/bin/bash

echo "============================================================"
echo "Preparations server"
echo "============================================================"
sudo -i
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install wget -y

cd $HOME
# следующие две команды могут выдать ошибку и это нормально
apt update && apt install curl -y && apt purge docker docker-engine docker.io containerd docker-compose -y
rm /usr/bin/docker-compose /usr/local/bin/docker-compose
curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh
systemctl restart docker
curl -SL https://github.com/docker/compose/releases/download/v2.5.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

echo "============================================================"
echo "Write the name of your node"
echo "============================================================"
read NODENAME
echo 'export NODENAME='${SUBSPACE_NODE_NAME} >> $HOME/.bash_profile
echo "============================================================"
echo "Enter your wallet address"
echo "============================================================"
read WALLETADDRESS
echo 'export WALLETADDRESS='$SUBSPACE_WALLET_ADDRESS >> $HOME/.bash_profile
echo "============================================================"
echo "Enter your plot size(Example: 50G)"
echo "============================================================"
read SUBSPACE_PLOT_SIZE
echo 'export SUBSPACE_PLOT_SIZE='$SUBSPACE_PLOT_SIZE >> $HOME/.bash_profile
source $HOME/.bash_profile

mkdir $HOME/subspace
cd $HOME/subspace
tee $HOME/subspace/docker-compose.yml > /dev/null <<EOF
version: "3.7"
services:
  node:
    # For running on Aarch64 add '-aarch64' after 'DATE'
    image: ghcr.io/subspace/node:gemini-1b-2022-june-03
    volumes:
# Instead of specifying volume (which will store data in '/var/lib/docker'), you can
# alternatively specify path to the directory where files will be stored, just make
# sure everyone is allowed to write there
      - node-data:/var/subspace:rw
#      - /path/to/subspace-node:/var/subspace:rw
    ports:
# If port 30333 is already occupied by another Substrate-based node, replace all
# occurrences of '30333' in this file with another value
      - "0.0.0.0:30334:30334"
    restart: unless-stopped
    command: [
      "--chain", "gemini-1",
      "--base-path", "/var/subspace",
      "--execution", "wasm",
      "--pruning", "1024",
      "--keep-blocks", "1024",
      "--port", "30334",
      "--rpc-cors", "all",
      "--rpc-methods", "safe",
      "--unsafe-ws-external",
      "--validator",
# Replace 'INSERT_YOUR_ID' with your node ID (will be shown in telemetry)
      "--name", "$SUBSPACE_NODE_NAME"
    ]
    healthcheck:
      timeout: 5s
# If node setup takes longer then expected, you want to increase 'interval' and 'retries' number.
      interval: 30s
      retries: 5

  farmer:
    depends_on:
      node:
        condition: service_healthy
# For running on Aarch64 add '-aarch64' after 'DATE'
    image: ghcr.io/subspace/farmer:gemini-1b-2022-june-03
# Un-comment following 2 lines to unlock farmer's RPC
#    ports:
#      - "127.0.0.1:9955:9955"
# Instead of specifying volume (which will store data in '/var/lib/docker'), you can
# alternatively specify path to the directory where files will be stored, just make
# sure everyone is allowed to write there
    volumes:
      - farmer-data:/var/subspace:rw
#      - /path/to/subspace-farmer:/var/subspace:rw
    restart: unless-stopped
    command: [
      "--base-path", "/var/subspace",
      "farm",
      "--node-rpc-url", "ws://node:9944",
      "--ws-server-listen-addr", "0.0.0.0:9955",
# Replace 'WALLET_ADDRESS' with your Polkadot.js wallet address
      "--reward-address", "$SUBSPACE_WALLET_ADDRESS",
# Replace 'PLOT_SIZE' with plot size in gigabytes or terabytes, for instance 100G or 2T (but leave at least 10G of disk space for node)
      "--plot-size", "$SUBSPACE_PLOT_SIZE"
    ]
volumes:
  node-data:
  farmer-data:
EOF


cd $HOME/subspace
docker-compose up -d
cd