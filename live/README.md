
使用帮助文档：
  https://www.jianshu.com/p/7dd4e1bee6d8
 
core.yaml 做了修改： golang.runtime=  
  
修改： ：
peer， orderer 是 1.4 版本的
core.yaml 中 baseos  做了固定的修改
采用connectionProfile 输入。  里面的url不能有grpc什么的，否则：context deadline exceeded 
----

cd `pwd`  ; ./orderer start

---

cd `pwd` ; ./peer node start

--- 

./byfn.sh createChannel

./byfn.sh joinChannel  

./byfn.sh updateAnchor

./byfn.sh installChaincode
# ./byfn.sh installChaincode


./byfn.sh instantiateChaincode

./byfn.sh invokeChaincode

./byfn.sh queryChaincode 
 


