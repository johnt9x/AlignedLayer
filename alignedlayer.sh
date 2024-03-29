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
curl -Ls https://raw.githubusercontent.com/vnbnode/binaries/main/Projects/AlignedLayer/genesis.json > $HOME/.alignedlayer/config/genesis.json
curl -Ls https://raw.githubusercontent.com/vnbnode/binaries/main/Projects/AlignedLayer/addrbook.json > $HOME/.alignedlayer/config/addrbook.json
sed -i \
  -e 's|^node *=.*|node = "tcp://localhost:24257"|' \
  $HOME/.alignedlayer/config/client.toml
sed -i -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:24258\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:24257\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:24260\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:24256\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":24266\"%" $HOME/.alignedlayer/config/config.toml
sed -i -e "s%^address = \"tcp://localhost:1317\"%address = \"tcp://0.0.0.0:24217\"%; s%^address = \":8080\"%address = \":24280\"%; s%^address = \"localhost:9090\"%address = \"0.0.0.0:24290\"%; s%^address = \"0.0.0.0:9091\"%address = \"0.0.0.0:24291\"%; s%:8545%:24245%; s%:8546%:24246%; s%:6065%:24265%" $HOME/.alignedlayer/config/app.toml

sed -i -e "s|^seeds *=.*|seeds = \"c355b86c882d05a83f84afba379291d7b954b28f@65.108.236.43:26656,b499b9eb88c1c78ae25fdc7c390090f7542160eb@167.235.12.38:26656,18e1adeadb8cc596375e4212288fcd00690df067@213.199.48.195:26656,d5f2890998932efb906eaa0070030ef3b5480a72@176.57.150.2:24256,6190cd77e6f17763fa6553f355bb4c8088560068@62.171.130.196:24256,68f7bbbeaa79fe5d1043d67f0ad75c03fce8d078@109.199.118.239:24256,2514706bb8a168d3e12e07c66e37a9b585abeeb4@37.60.232.236:24256,25442ec0368efe312539bf6b7bc8b436241497f9@62.171.130.220:24256\"|" $HOME/.alignedlayer/config/config.toml
sed -i -e 's|^persistent_peers *=.*|persistent_peers = "c355b86c882d05a83f84afba379291d7b954b28f@65.108.236.43:26656,b499b9eb88c1c78ae25fdc7c390090f7542160eb@167.235.12.38:26656,18e1adeadb8cc596375e4212288fcd00690df067@213.199.48.195:26656,d5f2890998932efb906eaa0070030ef3b5480a72@176.57.150.2:24256,6190cd77e6f17763fa6553f355bb4c8088560068@62.171.130.196:24256,68f7bbbeaa79fe5d1043d67f0ad75c03fce8d078@109.199.118.239:24256,2514706bb8a168d3e12e07c66e37a9b585abeeb4@37.60.232.236:24256,25442ec0368efe312539bf6b7bc8b436241497f9@62.171.130.220:24256"|' $HOME/.alignedlayer/config/config.toml

sudo systemctl daemon-reload
sudo systemctl enable alignedlayer
sudo systemctl restart alignedlayer

sleep 10

echo '=============== SETUP FINISHED ==================='
echo -e 'To check logs: \e[1m\e[32mjournalctl -u alignedlayer -f -o cat\e[0m'
echo -e "To check sync status: \e[1m\e[32mcurl -s localhost:24257/status | jq .result.sync_info\e[0m"
