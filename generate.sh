#!/bin/bash +x

#set -e

CHANNEL_NAME=$1
: ${CHANNEL_NAME:="mych"}
echo $CHANNEL_NAME

export PATH=$GOPATH/src/github.com/hyperledger/fabric/build/bin:${PWD}/bin:${PWD}:$PATH
export FABRIC_CFG_PATH=$PWD/network
echo

OS_ARCH=$(echo "$(uname -s)-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')

## Using docker-compose template replace private key file names with constants
function replacePrivateKey () {
	ARCH=`uname -s | grep Darwin`
	if [ "$ARCH" == "Darwin" ]; then
		OPTS="-it"
	else
		OPTS="-i"
	fi

	cp ./network/docker-compose-template.yaml ./network/docker-compose.yaml

    CURRENT_DIR=$PWD
    cd crypto-config/peerOrganizations/org1.example.com/ca/
    PRIV_KEY=$(ls *_sk)
    cd $CURRENT_DIR
    sed $OPTS "s/CA1_PRIVATE_KEY/${PRIV_KEY}/g" ./network/docker-compose.yaml

    #ca2
    cd crypto-config/peerOrganizations/org2.example.com/ca/
    PRIV_KEY=$(ls *_sk)
    cd $CURRENT_DIR
    sed $OPTS "s/CA2_PRIVATE_KEY/${PRIV_KEY}/g" ./network/docker-compose.yaml

    #ca3
    cd crypto-config/peerOrganizations/org3.example.com/ca/
    PRIV_KEY=$(ls *_sk)
    cd $CURRENT_DIR
    sed $OPTS "s/CA3_PRIVATE_KEY/${PRIV_KEY}/g" ./network/docker-compose.yaml

}

## Generates Org certs using cryptogen tool
function generateCerts (){
	echo
	echo "##########################################################"
	echo "##### Generate certificates using cryptogen tool #########"
	echo "##########################################################"
	cryptogen generate --config=./network/crypto-config.yaml
	echo
}

## Generate orderer genesis block , channel configuration transaction and anchor peer update transactions
function generateChannelArtifacts() {
	echo "##########################################################"
	echo "#########  Generating Orderer Genesis block ##############"
	echo "##########################################################"
	configtxgen -profile TwoOrgsOrdererGenesis -outputBlock ./channel-artifacts/orderer.genesis.block

	echo
	echo "#################################################################"
	echo "### Generating channel configuration transaction 'channel.tx' ###"
	echo "#################################################################"
	configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID $CHANNEL_NAME

	echo
	echo "#################################################################"
	echo "##### Generating anchor peer update for Org1MSP/Org2MSP      ####"
	echo "#################################################################"
	for orgMsp in Org1MSP Org2MSP Org3MSP; do
	    configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/${orgMsp}anchors.tx -channelID $CHANNEL_NAME -asOrg $orgMsp
        done
	echo
	echo

}

generateCerts
replacePrivateKey
generateChannelArtifacts

