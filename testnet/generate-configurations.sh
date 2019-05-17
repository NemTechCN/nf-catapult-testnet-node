#!/bin/bash

# NODE_IP defaults to 'api-node-0' in local environment
STATE_PATH=$1
ADDRESSES_PATH=$2
CONFIG_PATH=$3
NODE_IP=${4:-api-node-0}

# check presence of tools
CAT_BIN=`which cat`
GREP_BIN=`which grep`
TAIL_BIN=`which tail`
SED_BIN=`which sed`
AWK_BIN=`which awk`
GIT_BIN=`which git`
WGET_BIN=`which wget`

# verify current state
if [ -e ${STATE_PATH}/configs-edited ];
then
    echo "[ERROR] Configuration files have already been edited."
    exit 1
fi

# check for file presence
if [ -e ${ADDRESSES_PATH}/raw-addresses.txt ];
then
    echo 
else
    echo "[ERROR] Path '${ADDRESSES_PATH}' does not contain 'raw-addresses.txt' file."
    exit 2
fi

# read private keys from build/generated-addresses/raw-addresses.txt
read_private_key() {
    local key=`${CAT_BIN} ${ADDRESSES_PATH}/raw-addresses.txt | ${GREP_BIN} -m $1 'private key:' | ${AWK_BIN} '{print $3}' | ${TAIL_BIN} -1`
    echo "$key"
}

# read public keys from build/generated-addresses/raw-addresses.txt
read_public_key() {
    local key=`${CAT_BIN} ${ADDRESSES_PATH}/raw-addresses.txt | ${GREP_BIN} -m $1 'public key:' | ${AWK_BIN} '{print $3}' | ${TAIL_BIN} -1`
    echo "$key"
}

# read private keys
PRIVKEY_API_NODE=$(read_private_key 1)
PRIVKEY_PEER_NODE=$(read_private_key 2)
PRIVKEY_HARVEST=$(read_private_key 3)
PRIVKEY_REST=$(read_private_key 4)

# read public keys
PUBKEY_API_NODE=$(read_public_key 1)
PUBKEY_PEER_NODE=$(read_public_key 2)
PUBKEY_HARVEST=$(read_public_key 3)
PUBKEY_REST=$(read_public_key 4)

# configure the api-node-0 API node
config_api_node() {
    ## 1) change NODE_IP if not local
    ## 2) set bootKey
    ## 3) register neighboor peer node
    ## 4) register neighboor api node (self)
    ${SED_BIN} -i -e "s/api-node-0/${NODE_IP}/" ${CONFIG_PATH}/api-node-0/userconfig/resources/config-node.properties
    ${SED_BIN} -i -e "s/bootKey =.*/bootKey = ${PRIVKEY_API_NODE}/" ${CONFIG_PATH}/api-node-0/userconfig/resources/config-user.properties
    ${SED_BIN} -i -e "s/\"publicKey\": \"\"/\"publicKey\": \"${PUBKEY_PEER_NODE}\"/" ${CONFIG_PATH}/api-node-0/userconfig/resources/peers-p2p.json
    ${SED_BIN} -i -e "s/\"publicKey\": \"\"/\"publicKey\": \"${PUBKEY_API_NODE}\"/" ${CONFIG_PATH}/api-node-0/userconfig/resources/peers-api.json
}

# configure the peer-node-1 Peer node
config_peer_node() {
    ## 1) set harvestKey
    ## 2) set bootKey
    ## 3) register neighboor peer node (self)
    ## 4) register neighboor api node
    ${SED_BIN} -i -e "s/harvestKey =.*/harvestKey = ${PRIVKEY_HARVEST}/" ${CONFIG_PATH}/peer-node-1/userconfig/resources/config-harvesting.properties
    ${SED_BIN} -i -e "s/bootKey =.*/bootKey = ${PRIVKEY_PEER_NODE}/" ${CONFIG_PATH}/peer-node-1/userconfig/resources/config-user.properties
    ${SED_BIN} -i -e "s/\"publicKey\": \"\"/\"publicKey\": \"${PUBKEY_PEER_NODE}\"/" ${CONFIG_PATH}/peer-node-1/userconfig/resources/peers-p2p.json
    ${SED_BIN} -i -e "s/\"publicKey\": \"\"/\"publicKey\": \"${PUBKEY_API_NODE}\"/" ${CONFIG_PATH}/peer-node-1/userconfig/resources/peers-api.json
}

# configure the rest-gateway-0 REST gateway
config_rest_gateway() {
    ## 1) set harvestKey (clientPrivateKey)
    ## 2) set NODE_IP if not local
    ## 3) register neighboor api node
    ${SED_BIN} -i -e "s/\"clientPrivateKey\": \"\"/\"clientPrivateKey\": \"${PRIVKEY_HARVEST}\"/" ${CONFIG_PATH}/rest-gateway-0/userconfig/rest.json
    ${SED_BIN} -i -e "s/api-node-0/${NODE_IP}/" ${CONFIG_PATH}/rest-gateway-0/userconfig/rest.json
    ${SED_BIN} -i -e "s/\"publicKey\": \"\"/\"publicKey\": \"${PUBKEY_API_NODE}\"/" ${CONFIG_PATH}/rest-gateway-0/userconfig/rest.json
}

# save state with git
save_state_with_git() {
    ${GIT_BIN} checkout -b config-done
    ${GIT_BIN} add build/
    ${GIT_BIN} commit -m "testnet configuration done"
}

download_snapshot() {
    ${WGET_BIN} -O /tmp/api-node-data-190514.tar.gz  http://jp5.nemesis.land/share/api-node-data-190514.tar.gz
    tar xfzv /tmp/api-node-data-190514.tar.gz -C /testnet --overwrite
}

# temporary config state
touch ${STATE_PATH}/configs-generated

echo Now configuring api-node-0..
echo Using Private Key: ${PRIVKEY_API_NODE}
echo

# configure api-node-0
config_api_node

echo Now configuring peer-node-1..
echo Using Private Key: ${PRIVKEY_PEER_NODE}
echo

# configure peer-node-1
config_peer_node

echo Now configuring rest-gateway-0..
echo Using Private Key: ${PRIVKEY_REST}
echo

# configure rest-gateway-0
config_rest_gateway

# save configuration in git
save_state_with_git

# download snapshot
download_snapshot

# save config state
touch ${STATE_PATH}/configs-edited

echo Done configuring your Catapult Testnet node!

