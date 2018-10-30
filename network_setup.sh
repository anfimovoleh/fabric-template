#!/bin/bash

export FABRIC_CFG_PATH=$PWD/network

function usage () {
	echo
	echo "======================================================================================================"
	echo "Usage: "
	echo "      network_setup.sh -n [channel-name] -s -c <up|down|retstart>"
	echo
	echo "      ./network_setup.sh -n "mychannel" -c -s restart"
	echo
	echo "		-n       channel name"
	echo "		-c       enable couchdb"
	echo "		-s       Enable TLS"
	echo "		up       Launch the network and start the test"
	echo "		down     teardown the network and the test"
	echo "		restart  Restart the network and start the test"
	echo "======================================================================================================"
	echo
}

##process all the options
while getopts "scn:f:t:h" opt; do
  case "${opt}" in
    n)
      CH_NAME="$OPTARG"
      ;;
    c)
      COUCHDB="y" ## enable couchdb
      ;;
    s)
      SECURITY="y" #Enable TLS
      ;;
    h)
      usage
      exit 1
      ;;
    f)
      COMPOSE_FILE="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 1
      ;;
  esac
done

## this is to read the argument up/down/restart
shift $((OPTIND-1))
UP_DOWN="$@"

##Set Defaults
: ${CH_NAME:="mychannel"}
: ${SECURITY:="n"}
: ${COMPOSE_FILE:="docker-compose.yaml"}
: ${UP_DOWN:="restart"}
: ${CLI_TIMEOUT:="2"} ## Increase timeout for debugging purposes
: ${COUCHDB:="n"}

function clearContainers () {
        CONTAINER_IDS=$(docker ps -aq)
        if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" = " " ]; then
                echo "---- No containers available for deletion ----"
        else
                docker rm -f $CONTAINER_IDS
        fi
}

function removeUnwantedImages() {
        DOCKER_IMAGE_IDS=$(docker images | grep "dev\|none\|test-vp\|peer[0-9]-" | awk '{print $3}')
        if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" = " " ]; then
                echo "---- No images available for deletion ----"
        else
                docker rmi -f $DOCKER_IMAGE_IDS
        fi
}

function networkUp () {
    #Generate all the artifacts that includes org certs, orderer genesis block,
    # channel configuration transaction
#    source generate.sh $CH_NAME
    if [ "$SECURITY" == "y" -o "$SECURITY" == "Y" ]; then
        SECURITY=true
    else
        SECURITY=false
    fi
    if [ "$COUCHDB" == "y" -o "$COUCHDB" == "Y" ]; then
       ENABLE_TLS=$SECURITY CHANNEL_NAME=$CH_NAME docker-compose -f ./network/$COMPOSE_FILE -f ./network/docker-compose-couch.yaml up -d 2>&1
    else
       ENABLE_TLS=$SECURITY CHANNEL_NAME=$CH_NAME docker-compose -f ./network/$COMPOSE_FILE up -d 2>&1
    fi

    if [ $? -ne 0 ]; then
	    echo "ERROR !!!! Unable to pull the images "
	    exit 1
    fi
    printf "\n\n----------- Network is Ready ? -------------\n" 
    docker ps -a
    printf "\n--------------------------------------------------\n\n\n" 
}

function networkDown () {
    docker-compose -f ./network/$COMPOSE_FILE down

    #Cleanup the chaincode containers
    clearContainers

    #Cleanup images
    removeUnwantedImages

    #TODO ADD FLAG AND DO IT IF IT IS NEEDED
    # remove orderer block and other channel configuration transactions and certs
    rm -rf channel-artifacts/*.block channel-artifacts/*.tx crypto-config /tmp/hfc-test-kvs* $HOME/.hfc-key-store
}

#Create the network using docker compose
if [ "${UP_DOWN}" == "up" ]; then
	networkUp
	sleep 10s
elif [ "${UP_DOWN}" == "down" ]; then ## Clear the network
	networkDown
	networkDown
elif [ "${UP_DOWN}" == "restart" ]; then ## Restart the network
	networkDown
	networkUp
else
	usage
	exit 1
fi
