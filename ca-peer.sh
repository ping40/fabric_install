#!/bin/bash


MODE=$1
ROOTDIR=$2
ORG=$3
REVERSEORG=""

if [ "${ROOTDIR:0:1}" != "/" ]; then
	ROOTDIR=`pwd`/$ROOTDIR
fi

echo "ROOTDIR = $ROOTDIR"

FABRIC_CA_USER="kadminaskaldjfalkdsjf"
FABRIC_CA_PASSWORD="kangaroo$goup6"
ORDERER_FABRIC_CA_HOME="$ROOTDIR/ordererca"


function verifyResult() {
    if [ $1 -ne 0 ]; then
      echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
      echo
      exit 1
    fi
}

function mkmydir() {
	set -x
	mkdir $1
	res=$?
    set +x
	
	verifyResult $res "Channel creation failed"
	echo "===================== dir  '$1' created ===================== "
	echo
}

function start_fabric_ca_server() {
	set -x
	fabric-ca-server start -b $1:$2 -H $3 --cfg.affiliations.allowremove --cfg.identities.allowremove &
	res=$?
    set +x
	
	verifyResult $res "failed to start fabric-ca-server"
	echo "===================== start cs server successfully ===================== "
	echo
	sleep 1
}

function fabric_ca_server_enroll() {
	
	set -x
	fabric-ca-client enroll -u http://$1:$2@localhost:7054 -H $3
	res=$?
    set +x
	
	verifyResult $res "failed to enroll to  fabric-ca-server"
	echo "===================== enroll successfully===================== "
	echo
}

function fabric_ca_server_register_admin() {
	set -x
	
    fabric-ca-client register  -H $1  --id.name $2 --id.type client --id.affiliation "$REVERSEORG"   --id.secret $3 \
     --id.attrs '"hf.Registrar.Roles=client,orderer,peer,user","hf.Registrar.DelegateRoles=client,orderer,peer,user","hf.Registrar.Attributes=*","hf.GenCRL=true","hf.Revoker=true","hf.AffiliationMgr=true","hf.IntermediateCA=true","role=admin:ecert"'
  
	res=$?
    set +x
	
	verifyResult $res "failed to register"
	echo "===================== register successfully===================== "
	echo
}


function fabric_ca_server_register_org() {
	set -x
	
    fabric-ca-client register  -H $1  --id.name $2 --id.type peer --id.affiliation "$REVERSEORG"   --id.secret $3 
    # --id.attrs '"role=peer:ecert"'
  
	res=$?
    set +x
	
	verifyResult $res "failed to register"
	echo "===================== register org successfully===================== "
	echo
}


function fabric_ca_server_affiliation() {

	local prefixOrg=""
	local arr=(${ORG//./ })
	
	local arrLen=${#arr[@]}
	let arrLen--
	set -x  
	while [ $arrLen -ge 0 ]  
	do  
	    local item="${arr[$arrLen]}"
		if [ "$prefixOrg" = "" ]; then
			prefixOrg=$item
		else
			prefixOrg="$prefixOrg.$item"
		fi		
		fabric-ca-client -H $1 affiliation add $prefixOrg
		res=$?
		verifyResult $res "failed to affilicate"
		
		let arrLen--
	done
	
    set +x
	REVERSEORG="$prefixOrg"
	echo "===================== affilicate successfully===================== "
	echo
}

function fabric_ca_server_cert() {

    # 得到ca的证书
	fabric-ca-client getcacert -M  $1
	echo "===================== affilicate successfully===================== "
	echo
}


function create_org_info() {
	local orgRoot=$1
	local peer=$2
	
	mkmydir $orgRoot/$peer
	mkmydir $orgRoot/$peer/msp
	mkmydir $orgRoot/$peer/msp/admincerts
	
	# 得到ca的证书
	fabric_ca_server_cert  $orgRoot/$peer/msp
	cp $orgRoot/admin/msp/signcerts/* $orgRoot/$peer/msp/admincerts
	
	fabric_ca_server_register_org $orgRoot/admin  $peer@$ORG peerPassword
	fabric_ca_server_enroll $peer@$ORG peerPassword $orgRoot/$peer
	
    echo "===================== create $orgRoot/$peer successfully ===================== "
	echo
}

function start() {
	mkmydir $ROOTDIR/ca-server
	mkmydir $ROOTDIR/ca-admin
	mkmydir $ROOTDIR/org
	mkmydir $ROOTDIR/org/admin
	
	
	start_fabric_ca_server $FABRIC_CA_USER $FABRIC_CA_PASSWORD $ROOTDIR/ca-server
	
	fabric_ca_server_enroll $FABRIC_CA_USER $FABRIC_CA_PASSWORD $ROOTDIR/ca-admin
	fabric_ca_server_affiliation $ROOTDIR/ca-admin

	# 注册组织(org)的管理员，由ca-admin执行
	fabric_ca_server_register_admin $ROOTDIR/ca-admin  zhangsanadmin@$ORG password
	
	# 登陆 组织的管理员，由org-admin执行
	fabric_ca_server_enroll zhangsanadmin@$ORG password $ROOTDIR/org/admin
	
	mkmydir $ROOTDIR/org/admin/msp/admincerts
	cp $ROOTDIR/org/admin/msp/signcerts/* $ROOTDIR/org/admin/msp/admincerts/
	
	create_org_info $ROOTDIR/org peer0
	create_org_info $ROOTDIR/org peer1
	
}

function cleanup() {
    killpidbyport 7054
    
    set -x  
	local dest=$1
	rm -rf $dest/*
	res=$?
    set +x
      
	verifyResult $res "rm $dest failed"
	echo "=== rm $dest/* successfully === "
	echo
}


function killpidbyport() {
	kill $(lsof -t -i:$1)
}

function copycerts() {
	 rm -rf ordermsp/*
	 rm -rf org1msp/*
	 rm -rf org2msp/*
	
	 ./ca-peer.sh start ordermsp orderer.p.net
	 ./ca-peer.sh kill
	 
	 ./ca-peer.sh start org1msp org1.p.net
	 ./ca-peer.sh kill
	 
	 
	 ./ca-peer.sh start org2msp org2.p.net
	 ./ca-peer.sh kill
	 
	rm -rf crypto-config/*
	
	# orderer 
	mkdir -p crypto-config/ordererOrganizations/ping40.net/orderers/orderer.ping40.net/
	mkdir -p crypto-config/ordererOrganizations/ping40.net/users/Admin@ping40.net
	cp -rf ordermsp/org/admin/msp crypto-config/ordererOrganizations/ping40.net/
	cp -rf ordermsp/org/peer0/msp crypto-config/ordererOrganizations/ping40.net/orderers/orderer.ping40.net/
	cp -rf ordermsp/org/admin/msp crypto-config/ordererOrganizations/ping40.net/users/Admin@ping40.net


	#org1 peer0/peer1
	mkdir -p crypto-config/peerOrganizations/org1.ping40.net/peers/peer0.org1.ping40.net
	mkdir -p crypto-config/peerOrganizations/org1.ping40.net/peers/peer1.org1.ping40.net
	mkdir -p crypto-config/peerOrganizations/org1.ping40.net/users/Admin@org1.ping40.net
	
	cp -rf org1msp/org/admin/msp crypto-config/peerOrganizations/org1.ping40.net
	cp -rf org1msp/org/peer0/msp crypto-config/peerOrganizations/org1.ping40.net/peers/peer0.org1.ping40.net
	cp -rf org1msp/org/peer1/msp crypto-config/peerOrganizations/org1.ping40.net/peers/peer1.org1.ping40.net
	cp -rf org1msp/org/admin/msp crypto-config/peerOrganizations/org1.ping40.net/users/Admin@org1.ping40.net
	cp config.yaml crypto-config/peerOrganizations/org1.ping40.net/msp

    #org2 peer0/peer1
	mkdir -p crypto-config/peerOrganizations/org2.ping40.net/peers/peer0.org2.ping40.net
	mkdir -p crypto-config/peerOrganizations/org2.ping40.net/peers/peer1.org2.ping40.net
	mkdir -p crypto-config/peerOrganizations/org2.ping40.net/users/Admin@org2.ping40.net
	
	cp -rf org2msp/org/admin/msp crypto-config/peerOrganizations/org2.ping40.net
	cp -rf org2msp/org/peer0/msp crypto-config/peerOrganizations/org2.ping40.net/peers/peer0.org2.ping40.net
	cp -rf org2msp/org/peer1/msp crypto-config/peerOrganizations/org2.ping40.net/peers/peer1.org2.ping40.net
	cp -rf org2msp/org/admin/msp crypto-config/peerOrganizations/org2.ping40.net/users/Admin@org2.ping40.net
	cp config.yaml crypto-config/peerOrganizations/org2.ping40.net/msp
    
}

if [ "${MODE}" == "cleanup" ]; then
    cleanup $ROOTDIR
elif [ "${MODE}" == "start" ]; then 
    start $ROOTDIR
elif [ "${MODE}" == "kill" ]; then 
    killpidbyport 7054
elif [ "${MODE}" == "copycerts" ]; then 
    copycerts
else
    echo "wrong commander: '${MODE}'"
fi





