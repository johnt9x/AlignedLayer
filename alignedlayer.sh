#!/bin/bash
# Prompt for the moniker
read -p "Enter your moniker (a short name for your node): " MONIKER

# Check if the MONIKER is empty and prompt again until it's not empty
while [ -z "$MONIKER" ]; do
    read -p "Moniker cannot be empty. Please enter your moniker: " MONIKER
done

clear

if [[ ! -f "$HOME/.bash_profile" ]]; then
    touch "$HOME/.bash_profile"
fi

if [ -f "$HOME/.bash_profile" ]; then
    source $HOME/.bash_profile
fi

sudo apt update && apt upgrade -y
sudo apt install curl git wget htop tmux build-essential jq make lz4 gcc unzip -y

#Install GO
ver="1.21.4"
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
rm "go$ver.linux-amd64.tar.gz"
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> $HOME/.bash_profile
source $HOME/.bash_profile
go version

cd $HOME
wget https://github.com/yetanotherco/aligned_layer_tendermint/releases/download/v0.1.0/alignedlayerd
chmod +x alignedlayerd
sudo mv alignedlayerd /usr/local/bin/
cd $HOME
alignedlayerd version

NODE_HOME=$HOME/.alignedlayer
CHAIN_BINARY=alignedlayerd
CHAIN_ID=alignedlayer

sudo rm -rf NODE_HOME

: ${PEER_ADDR="91.107.239.79,116.203.81.174,88.99.174.203,128.140.3.188"}

PEER_ARRAY=(${PEER_ADDR//,/ })
: ${MINIMUM_GAS_PRICES="0.0001stake"}

$CHAIN_BINARY comet unsafe-reset-all
$CHAIN_BINARY init $MONIKER \
    --chain-id $CHAIN_ID --overwrite

for ADDR in "${PEER_ARRAY[@]}"; do
    GENESIS=$(curl -f "$ADDR:26657/genesis" | jq '.result.genesis')
    if [ -n "$GENESIS" ]; then
        echo "$GENESIS" > $NODE_HOME/config/genesis.json;
        break;
    fi
done

PERSISTENT_PEERS=()

for ADDR in "${PEER_ARRAY[@]}"; do
    PEER_ID=$(curl -s "$ADDR:26657/status" | jq -r '.result.node_info.id')
    if [ -n "$PEER_ID" ]; then
        PERSISTENT_PEERS+=("$PEER_ID@$ADDR:26656")
    fi
done

CONFIG_STRING=$(IFS=,; echo "${PERSISTENT_PEERS[*]}")

$CHAIN_BINARY config set config p2p.persistent_peers "$CONFIG_STRING" --skip-validate

sudo tee /etc/systemd/system/alignedlayer.service > /dev/null <<EOF
[Unit]
Description=alignedlayerd
After=network-online.target
[Service]
User=root
ExecStart=$(which alignedlayerd) start
Restart=always
RestartSec=3
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF
cd $HOME
sed -i \
  -e 's|^node *=.*|node = "tcp://localhost:24257"|' \
  $HOME/.alignedlayer/config/client.toml

sed -i -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:24258\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:24257\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:24260\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:24256\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":24266\"%" $HOME/.alignedlayer/config/config.toml
sed -i -e "s%^address = \"tcp://localhost:1317\"%address = \"tcp://0.0.0.0:24217\"%; s%^address = \":8080\"%address = \":24280\"%; s%^address = \"localhost:9090\"%address = \"0.0.0.0:24290\"%; s%^address = \"0.0.0.0:9091\"%address = \"0.0.0.0:24291\"%; s%:8545%:24245%; s%:8546%:24246%; s%:6065%:24265%" $HOME/.alignedlayer/config/app.toml

sed -i -e "s|^seeds *=.*|seeds = \"a1a98d9caf27c3363fab07a8e57ee0927d8c7eec@128.140.3.188:26656,1beca410dba8907a61552554b242b4200788201c@91.107.239.79:26656,f9000461b5f535f0c13a543898cc7ac1cd10f945@88.99.174.203:26656,ca2f644f3f47521ff8245f7a5183e9bbb762c09d@116.203.81.174:26656,dc2011a64fc5f888a3e575f84ecb680194307b56@148.251.235.130:20656,6190cd77e6f17763fa6553f355bb4c8088560068@62.171.130.196:24256,a1a98d9caf27c3363fab07a8e57ee0927d8c7eec@128.140.3.188:26656,1beca410dba8907a61552554b242b4200788201c@91.107.239.79:26656,f9000461b5f535f0c13a543898cc7ac1cd10f945@88.99.174.203:26656,ca2f644f3f47521ff8245f7a5183e9bbb762c09d@116.203.81.174:26656,dc2011a64fc5f888a3e575f84ecb680194307b56@148.251.235.130:20656\"|" $HOME/.alignedlayer/config/config.toml
sed -i -e 's|^persistent_peers *=.*|persistent_peers = "a1a98d9caf27c3363fab07a8e57ee0927d8c7eec@128.140.3.188:26656,1beca410dba8907a61552554b242b4200788201c@91.107.239.79:26656,f9000461b5f535f0c13a543898cc7ac1cd10f945@88.99.174.203:26656,ca2f644f3f47521ff8245f7a5183e9bbb762c09d@116.203.81.174:26656,dc2011a64fc5f888a3e575f84ecb680194307b56@148.251.235.130:20656,6190cd77e6f17763fa6553f355bb4c8088560068@62.171.130.196:24256,a1a98d9caf27c3363fab07a8e57ee0927d8c7eec@128.140.3.188:26656,1beca410dba8907a61552554b242b4200788201c@91.107.239.79:26656,f9000461b5f535f0c13a543898cc7ac1cd10f945@88.99.174.203:26656,ca2f644f3f47521ff8245f7a5183e9bbb762c09d@116.203.81.174:26656,dc2011a64fc5f888a3e575f84ecb680194307b56@148.251.235.130:20656"|' $HOME/.alignedlayer/config/config.toml

sudo systemctl daemon-reload
sudo systemctl enable alignedlayer
sudo systemctl restart alignedlayer

sleep 10

echo '=============== SETUP FINISHED ==================='
echo -e 'To check logs: \e[1m\e[32mjournalctl -u alignedlayer -f -o cat\e[0m'
echo -e "To check sync status: \e[1m\e[32mcurl -s localhost:24257/status | jq .result.sync_info\e[0m"
