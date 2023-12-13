#!/bin/sh

set -x

JSON_RPC="http://localhost:8545"

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

# start geth in a local container
docker container run --rm -d --name deployment-proxy-geth -p 1234:8545 -e GETH_VERBOSITY=3 keydonix/geth-clique
# wait for geth to become responsive
until curl --silent --fail $JSON_RPC -X 'POST' -H 'Content-Type: application/json' --data "{\"jsonrpc\":\"2.0\", \"id\":1, \"method\": \"net_version\", \"params\": []}"; do sleep 1; done

# extract the variables we need from json output
TRANSACTION="0x$(cat output/deployment.json | jq --raw-output '.transaction')"
DEPLOYER_ADDRESS="0x$(cat output/deployment.json | jq --raw-output '.address')"

# deploy the deployer contract
curl $JSON_RPC -X 'POST' -H 'Content-Type: application/json' --data "{\"jsonrpc\":\"2.0\", \"id\":1, \"method\": \"eth_sendRawTransaction\", \"params\": [\"$TRANSACTION\"]}"

# shutdown Parity
docker container stop deployment-proxy-geth
