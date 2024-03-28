#!/bin/bash
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


MONIKER="MyNode"
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
sudo systemctl daemon-reload
sudo systemctl enable alignedlayer
sudo systemctl restart alignedlayer

sleep 10

echo '=============== SETUP FINISHED ==================='
echo -e 'To check logs: \e[1m\e[32mjournalctl -u alignedlayer -f -o cat\e[0m'
echo -e "To check sync status: \e[1m\e[32mcurl -s localhost:26657/status | jq .result.sync_info\e[0m"
