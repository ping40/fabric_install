#!/bin/bash

# one machine

# 127.0.0.1 peer0.org1.ping40.net 51100
# 127.0.0.1 peer1.org1.ping40.net 51110
# 127.0.0.1 peer0.org2.ping40.net 51200
# 127.0.0.1 peer1.org2.ping40.net 51210
# 127.0.0.1    orderer0.ping40.net 51000
# 127.0.0.1    orderer1.ping40.net 51001
# 127.0.0.1    orderer2.ping40.net 51002
# 127.0.0.1    kafka0.ping40.net
# 127.0.0.1    kafka1.ping40.net
# 127.0.0.1    kafka2.ping40.net
# 127.0.0.1    kafka3.ping40.net


# five machines
# 192.168.64.136 peer0.org1.ping40.net 51100
# 192.168.64.225 peer1.org1.ping40.net 51110
# 192.168.64.243 peer0.org2.ping40.net 51200
# 192.168.64.249 peer1.org2.ping40.net 51210
# 192.168.64.69    orderer0.ping40.net 51000
# 192.168.64.69    orderer1.ping40.net 51001
# 192.168.64.69    orderer2.ping40.net 51002


MODE=$1
# channel name defaults to "mychannel"
CHANNEL_NAME="ping40channel"
CHAINCODENAME="chaincodeName"
CHAINCODEVERSION="3.1"
CURRENTDIR=`pwd`
echo "CURRENTDIR = $CURRENTDIR"

ORDERER_CA=$CURRENTDIR/crypto-config/ordererOrganizations/ping40.net/orderers/orderer0.ping40.net/msp/tlscacerts/tlsca.ping40.net-cert.pem
PEER0_ORG1_CA=$CURRENTDIR/crypto-config/peerOrganizations/org1.ping40.net/peers/peer0.org1.ping40.net/tls/ca.crt
PEER0_ORG2_CA=$CURRENTDIR/crypto-config/peerOrganizations/org2.ping40.net/peers/peer0.org2.ping40.net/tls/ca.crt
# Print the usage message
function printHelp() {
    echo "Usage: "
    echo "  byfn.sh <mode>"
    echo "    - 'generate' - generate required certificates and genesis block"
    echo "    - 'cleanup' - "
    echo "    - 'dispatch' - 执行这个命令后，可以把相关目录复制到各个机器上"
    echo "    - 'runOrderer' - "
    echo "    - 'createChannel' - "
    echo "    - 'installChaincode' - "
    echo "    - 'instantiateChaincode' - "
    echo "    - 'invokeChaincode' - "
    echo "    - 'updateAnchor' - "
    echo "    - 'queryChaincode' - "  
    echo "    - 'joinChannel' - "
}

# Generates Org certs using cryptogen tool
function generateCerts() {
    echo
    echo "##########################################################"
    echo "##### Generate certificates using cryptogen tool #########"
    echo "##########################################################"

    if [ -d "crypto-config" ]; then
      rm -Rf crypto-config
    fi
    set -x
    ./cryptogen generate --config=./crypto-config.yaml
    res=$?
    set +x
    if [ $res -ne 0 ]; then
      echo "Failed to generate certificates..."
      exit 1
    fi
    echo
}


function generateChannelArtifacts() {
  
    if [ -d "channel-artifacts" ]; then
      rm -rf channel-artifacts/*
    fi
    mkdir channel-artifacts
    echo "##########################################################"
    echo "#########  Generating Orderer Genesis block ##############"
    echo "##########################################################"
    # Note: For some unknown reason (at least for now) the block file can't be
    # named orderer.genesis.block or the orderer will fail to launch!
    set -x
    ./configtxgen -profile TwoOrgsOrdererGenesis -outputBlock ./channel-artifacts/mygenesis.block
    res=$?
    set +x
    if [ $res -ne 0 ]; then
      echo "Failed to generate orderer genesis block..."
      exit 1
    fi
    echo
    echo "#################################################################"
    echo "### Generating channel configuration transaction 'channel.tx' ###"
    echo "#################################################################"
    set -x
    ./configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID $CHANNEL_NAME
    res=$?
    set +x
    if [ $res -ne 0 ]; then
      echo "Failed to generate channel configuration transaction..."
      exit 1
    fi

    echo
    echo "#################################################################"
    echo "#######    Generating anchor peer update for part-a-supply   ##########"
    echo "#################################################################"
    set -x
    ./configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg part-a-supply
    res=$?
    set +x
    if [ $res -ne 0 ]; then
      echo "Failed to generate anchor peer update for part-a-supply..."
      exit 1
    fi

    echo
    echo "#################################################################"
    echo "#######    Generating anchor peer update for big-tech-company   ##########"
    echo "#################################################################"
    set -x
    ./configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate \
      ./channel-artifacts/Org2MSPanchors.tx -channelID $CHANNEL_NAME -asOrg big-tech-company
    res=$?
    set +x
    if [ $res -ne 0 ]; then
      echo "Failed to generate anchor peer update for big-tech-company..."
      exit 1
    fi
    echo
}


function disptchFiles() {
    echo
    echo "##########################################################"
    echo "##### copy files to run-orderer, run-peer0-org1 #########"
    echo "##### run-peer1-org1, run-peer0-org2,run-peer1-org2######"
    echo "##########################################################"

    cd $CURRENTDIR
    mkdir multimachine  
    
    disptchFile4Orderer 0
    disptchFile4Orderer 1
    disptchFile4Orderer 2
    
    disptchFile4Peer 0 1
    disptchFile4Peer 1 1
    disptchFile4Peer 0 2
    disptchFile4Peer 1 2 
}


function disptchFile4Orderer() {
    NUM=$1
    
    rm -rf run-orderer${NUM}
    mkdir run-orderer${NUM}
    cp orderer run-orderer${NUM}/
    cp channel-artifacts/mygenesis.block run-orderer${NUM}/
    cp -r crypto-config/ordererOrganizations/ping40.net/orderers/orderer${NUM}.ping40.net/msp/ run-orderer${NUM}/
    cp -r crypto-config/ordererOrganizations/ping40.net/orderers/orderer${NUM}.ping40.net/tls/ run-orderer${NUM}/
    cp orderer${NUM}.yaml run-orderer${NUM}/orderer.yaml
    
    tar -czvf multimachine/run-orderer${NUM}.tar.gz  run-orderer${NUM}/
}


function disptchFile4Peer() {
    PEER=$1
    ORG=$2
 
    cd $CURRENTDIR
    mydir=run-peer$PEER-org$ORG
    rm -rf $mydir
    mkdir $mydir
    cp peer $mydir/
    cp peer$PEER-org$ORG.core.yaml $mydir/core.yaml
    cp -r crypto-config/peerOrganizations/org$ORG.ping40.net/peers/peer$PEER.org$ORG.ping40.net/msp/ $mydir/
    cp -r crypto-config/peerOrganizations/org$ORG.ping40.net/peers/peer$PEER.org$ORG.ping40.net/tls/ $mydir/
    
    tar -czvf multimachine/$mydir.tar.gz  $mydir/
}

function runOrderer() {
    echo
    echo "##########################################################"
    echo "##### 请到 目录run-orderer 下执行 ./orderer start      #####"
    echo "#########################################################"
    
}

function runPeer() {
    echo
    echo "#################################################################"
    echo "##### 请到目录run-peer0/1-org1/2 下执行 ./peer node start     #####"
    echo "################################################################"
}

function cleanup() {
    echo
    echo "##########################################################"
    echo "##### cleanup #####"
    echo "##########################################################"

    rm -rf crypto-config/
    rm -rf channel-artifacts/
    rm -rf run-orderer0/  
    rm -rf run-orderer1/  
    rm -rf run-orderer2/
      
    rm -rf run-peer0-org1/
    rm -rf run-peer1-org1/
    rm -rf run-peer0-org2/
    rm -rf run-peer1-org2/
    rm -rf multimachine/
    rm -rf log.txt/
    if [ -f "${CHANNEL_NAME}.block" ]; then
      rm -rf ${CHANNEL_NAME}.block
    fi
        
}

function createChannel() {
	cd $CURRENTDIR/
    PEER=$1
    ORG=$2 
	setGlobals $PEER $ORG
	set -x
	CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE \
	CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS  \
	./peer channel create -o orderer0.ping40.net:51000 -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx  --tls true --cafile $ORDERER_CA --logging-level=debug 2>log.txt
	res=$?
    set +x
	
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo "===================== Channel '$CHANNEL_NAME' created ===================== "
	echo
}

function joinChannel() {
	cd $CURRENTDIR/
	PEER=$1
    ORG=$2 
	setGlobals $PEER $ORG
	
	set -x
	CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE \
	CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS \
	./peer channel join -b ping40channel.block --logging-level=debug 2>log.txt
	res=$?
    set +x
	
	cat log.txt
	verifyResult $res "joinChannel peer$1-org$2 failed"
	echo "===================== peer$1-org$2.ping40.net success to join channel ===================== "
	echo
}

function installChaincode() {
	cd $CURRENTDIR/
	PEER=$1
    ORG=$2 
	setGlobals $PEER $ORG
	
	set -x
	CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE \
	GOPATH=$CURRENTDIR \
	CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS \
	./peer chaincode install -n $CHAINCODENAME -v $CHAINCODEVERSION -p chaincode/ --logging-level=debug 2>log.txt

	res=$?
    set +x
	
	cat log.txt
	verifyResult $res "installChaincode peer$1-org$2 failed"
	echo "===================== peer$1-org$2.ping40.net success to installChaincode ===================== "
	echo
}

function instantiateChaincode() {
	cd $CURRENTDIR/
	PEER=$1
    ORG=$2 
	setGlobals $PEER $ORG
	
	set -x
	CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE \
	CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS \
	./peer chaincode instantiate -o orderer0.ping40.net:51000 -C $CHANNEL_NAME  -n $CHAINCODENAME -v $CHAINCODEVERSION \
	--tls \
	--cafile $ORDERER_CA \
	-c '{"Args":["init","a","100","b","200"]}'  -P "OR ('Org1MSP.member', 'Org2MSP.member')" --logging-level=debug 2>log.txt
	res=$?
    set +x
	
	cat log.txt
	verifyResult $res "instantiateChaincode peer$1-org$2 failed"
	echo "===================== peer$1-org$2.ping40.net success to instantiateChaincode ===================== "
	echo
}

function invokeChaincode() {
    cd $CURRENTDIR/
    PEER=$1
    ORG=$2 
    setGlobals $PEER $ORG
	
    set -x
    CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE \
    CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS \
    ./peer chaincode invoke -o orderer0.ping40.net:51000 -C $CHANNEL_NAME \
    --tls \
	--cafile $ORDERER_CA \
	-n $CHAINCODENAME  -c '{"Args":["invoke","a","b","10"]}'  >&log.txt
    res=$?
    set +x
    cat log.txt
    verifyResult $res "Invoke execution on peer$1-org$2 failed "
    echo "===================== Invoke transaction successful on $PEERS on channel '$CHANNEL_NAME' ===================== "
    echo
}

function queryChaincode() {
    cd $CURRENTDIR/
    PEER=$1
    ORG=$2 
    setGlobals $PEER $ORG
    set -x
    CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE \
    CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS \
    ./peer chaincode query -C $CHANNEL_NAME -n $CHAINCODENAME -c '{"Args":["query","a"]}' >&log.txt
    res=$?
    set +x
    echo
    cat log.txt
    
    verifyResult $res "queryChaincode  on peer$1-org$2 failed "
    echo "========= Query successful on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME' ===================== "
}

function updateAnchor() {
	cd $CURRENTDIR/
	PEER=$1
    ORG=$2 
	setGlobals $PEER $ORG
	
	set -x
	CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE \
	CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS \
	./peer channel update -o orderer0.ping40.net:51000 -c $CHANNEL_NAME -f channel-artifacts/Org${ORG}MSPanchors.tx --tls true --cafile $ORDERER_CA --logging-level=debug 2>log.txt
	res=$?
    set +x
	
	cat log.txt
	verifyResult $res "updateAnchor peer$1-org$2 failed"
	echo "===================== peer$1-org$2.ping40.net success to updateAnchor ===================== "
	echo
}

function verifyResult() {
    if [ $1 -ne 0 ]; then
      echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
      echo "========= ERROR !!! FAILED to execute End-2-End Scenario ==========="
      echo
      exit 1
    fi
}

function setGlobals() {
  
    PEER=$1
    ORG=$2
  
    echo "00 setGlobals $PEER, $ORG"
    if [ $ORG -eq 1 ]; then
      echo "02 setGlobals $PEER, $ORG"
      CORE_PEER_LOCALMSPID="Org1MSP"
      CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG1_CA
      CORE_PEER_MSPCONFIGPATH=$CURRENTDIR/crypto-config/peerOrganizations/org1.ping40.net/users/Admin@org1.ping40.net/msp
      if [ $PEER -eq 0 ]; then
        CORE_PEER_ADDRESS=peer0.org1.ping40.net:51100
      else
        CORE_PEER_ADDRESS=peer1.org1.ping40.net:51110
      fi
    elif [ $ORG -eq 2 ]; then
      CORE_PEER_LOCALMSPID="Org2MSP"
      CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG2_CA
      CORE_PEER_MSPCONFIGPATH=$CURRENTDIR/crypto-config/peerOrganizations/org2.ping40.net/users/Admin@org2.ping40.net/msp
      if [ $PEER -eq 0 ]; then
        CORE_PEER_ADDRESS=peer0.org2.ping40.net:51200
      else
        CORE_PEER_ADDRESS=peer1.org2.ping40.net:51210
      fi
    fi
  
    echo "CORE_PEER_ADDRESS: $CORE_PEER_ADDRESS "
    echo "CORE_PEER_LOCALMSPID: $CORE_PEER_LOCALMSPID"
    echo "CORE_PEER_MSPCONFIGPATH: $CORE_PEER_MSPCONFIGPATH"
    echo "environment variables: begin"
    env | grep CORE
    echo "environment variables: end"
  
 }

if [ "${MODE}" == "cleanup" ]; then
    cleanup
elif [ "${MODE}" == "dispatch" ]; then ## 复制文件到相应独立目录中
    disptchFiles
elif [ "${MODE}" == "runOrderer" ]; then 
    runOrderer
elif [ "${MODE}" == "createChannel" ]; then
    createChannel 0 1
elif [ "${MODE}" == "installChaincode" ]; then
    installChaincode 0 1
    installChaincode 0 2
elif [ "${MODE}" == "instantiateChaincode" ]; then
    instantiateChaincode 0 2
elif [ "${MODE}" == "invokeChaincode" ]; then
    invokeChaincode 0 1
    invokeChaincode 0 2
    echo "几乎同时触发二个transaction，其中一个会失败的"
elif [ "${MODE}" == "updateAnchor" ]; then
    updateAnchor 0 1
    updateAnchor 0 2
elif [ "${MODE}" == "queryChaincode" ]; then
    queryChaincode 0 1
    queryChaincode 0 2
elif [ "${MODE}" == "invokeChaincode" ]; then
    invokeChaincode 0 1
    invokeChaincode 0 2
elif [ "${MODE}" == "joinChannel" ]; then
    joinChannel 0 1
    joinChannel 1 1
    joinChannel 0 2
    joinChannel 1 2
elif [ "${MODE}" == "generate" ]; then ## Generate Artifacts
    generateCerts
    generateChannelArtifacts
else
    printHelp
    echo "wrong commander: '${MODE}'"
fi



