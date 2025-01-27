#!/bin/sh

set -x

if [ -z "$1" ]; then
    echo "Usage: $0 <JSON_RPC_URL>"
    exit 1
fi
JSON_RPC="$1"

if ! [ -x "$(command -v curl)" ]; then
    echo "Curl must be installed to deploy the create2 proxy" >&2
    exit 1
fi

# Check if contract already deployed
DATA='{"jsonrpc":"2.0","method":"eth_getCode","params":["0x4e59b44847b379578588920ca78fbf26c0b4956c", "latest"],"id":1}'
RESPONSE=$(curl -s -X POST --data "$DATA" -H "Content-Type: application/json" http://localhost:8545)
CODE=$(echo $RESPONSE | jq -r '.result')
if [ "$CODE" != "0x" ]; then
    echo "Contract already deployed at 0x4e59b44847b379578588920ca78fbf26c0b4956c"
    exit 0
else
    echo "No contract deployed at 0x4e59b44847b379578588920ca78fbf26c0b4956c. Deploying..."
fi

# Check deployment signer has balance of 10000000000000000 wei allocated from genesis
RESPONSE=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0x3fab184622dc19b6109349b94811493bf2a45362", "latest"],"id":1}' -H "Content-Type: application/json" $JSON_RPC)
if [ $(echo $RESPONSE | jq -r '.result') != "0x2386f26fc10000" ]; then
    echo "Deployment signer (0x3fab184622dc19b6109349b94811493bf2a45362) must have balance of 10000000000000000 wei"
    exit 1
fi

# Set presigned transaction 
TRANSACTION="0xf8a58085174876e800830186a08080b853604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf31ba02222222222222222222222222222222222222222222222222222222222222222a02222222222222222222222222222222222222222222222222222222222222222"

# deploy contract 
curl $JSON_RPC -X 'POST' -H 'Content-Type: application/json' --data "{\"jsonrpc\":\"2.0\", \"id\":1, \"method\": \"eth_sendRawTransaction\", \"params\": [\"$TRANSACTION\"]}"

sleep 5

# For prod we'll have to set gas params s.t. no ether is leftover here. For now we warn
RESPONSE=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0x3fab184622dc19b6109349b94811493bf2a45362", "latest"],"id":1}' -H "Content-Type: application/json" $JSON_RPC)
if [ $(echo $RESPONSE | jq -r '.result') != "0x0" ]; then
    echo "WARNING: Deployment signer (0x3fab184622dc19b6109349b94811493bf2a45362) has leftover balance of $(echo $RESPONSE | jq -r '.result') wei"
fi


