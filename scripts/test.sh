#!/bin/sh

set -x

JSON_RPC="http://localhost:8545"

# start geth in a local container
docker container run --rm -d --name deployment-proxy-geth -p 1234:8545 -e GETH_VERBOSITY=3 keydonix/geth-clique
# wait for geth to become responsive
until curl --silent --fail $JSON_RPC -X 'POST' -H 'Content-Type: application/json' --data "{\"jsonrpc\":\"2.0\", \"id\":1, \"method\": \"net_version\", \"params\": []}"; do sleep 1; done

# extract the variables we need from json output
MY_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" # Funded on genesis
ONE_TIME_SIGNER_ADDRESS="0x$(cat output/deployment.json | jq --raw-output '.signerAddress')"
GAS_COST="0x$(printf '%x' $(($(cat output/deployment.json | jq --raw-output '.gasPrice') * $(cat output/deployment.json | jq --raw-output '.gasLimit'))))"
TRANSACTION="0x$(cat output/deployment.json | jq --raw-output '.transaction')"
DEPLOYER_ADDRESS="0x$(cat output/deployment.json | jq --raw-output '.address')"

# send gas money to signer
curl $JSON_RPC -X 'POST' -H 'Content-Type: application/json' --data "{\"jsonrpc\":\"2.0\", \"id\":1, \"method\": \"eth_sendTransaction\", \"params\": [{\"from\":\"$MY_ADDRESS\",\"to\":\"$ONE_TIME_SIGNER_ADDRESS\",\"value\":\"$GAS_COST\"}]}"

# deploy the deployer contract
curl $JSON_RPC -X 'POST' -H 'Content-Type: application/json' --data "{\"jsonrpc\":\"2.0\", \"id\":1, \"method\": \"eth_sendRawTransaction\", \"params\": [\"$TRANSACTION\"]}"

# shutdown Parity
docker container stop deployment-proxy-geth
