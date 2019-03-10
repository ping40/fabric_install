## 条件

本程序使用sarama， 支持 Apache Kafka 0.8, and up.

## 启动kafka

修改配置文件：

      - KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://192.168.3.3:9092
      这个192.168.3.3 修改为本地能够认识的ip/dns
      
       docker-compose -f kafka-cluster.yaml  up

## 证明 kafka成功启动

 进入 kafka docker， 执行：

root@2c923a16c19b:/opt/kafka/bin# ./bin/kafka-topics.sh --create --zookeeper zookeeper.example.com:2181 --replication-factor 1 --partitions 1 --topic test123  

Created topic "test123".

root@bcd1ae549ab2:/opt/kafka# bin/kafka-console-producer.sh --broker-list localhost:9092 --topic test123
>1234
>222
>3333
>4444
>^Croot@bcd1ae549ab2:/opt/kafka# 
root@bcd1ae549ab2:/opt/kafka# cat /tmp/kafka-logs/replication-offset-checkpoint 
0
1
test123 0 4   --》 查看出这个topic的offset的值

## 运行程序

```go
kiki@me:/gp/src/github.com/ping40/fabric_install/kafka_insert$ ./main  -topic test123 -count 1000000
2019/03/10 12:35:08 > message sent to partition 0 at offset 110000
2019/03/10 12:35:11 > message sent to partition 0 at offset 120000
2019/03/10 12:35:13 > message sent to partition 0 at offset 130000
2019/03/10 12:35:16 > message sent to partition 0 at offset 140000
......
2019/03/10 12:39:21 > message sent to partition 0 at offset 1090000
2019/03/10 12:39:23 > message sent to partition 0 at offset 1100000
2019/03/10 12:39:23 > elapsed: 4m17.535221141s,  1000000
kiki@me:/gp/src/github.com/ping40/fabric_install/kafka_insert$ 


root@6010ef544f42:/# cat /tmp/kafka-logs/replication-offset-checkpoint 
0
1
test123 0 1100003  --> 目前offset = 1100003
root@6010ef544f42:/#
```

