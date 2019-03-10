package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/Shopify/sarama"
)

var (
	kafkaServer = flag.String("kafka-servers", "localhost:9092", "kafka servers, such as localhost:9092,localhost:9091 ")
	topic       = flag.String("topic", "ping40topic", "kafka topic name")
	count       = flag.Int64("count", 123, "the count message which sent to kafka")
)

func main() {
	flag.Parse()
	if *count < 0 {
		log.Printf("illegal count: %d\n", *count)
		os.Exit(-1)
	}

	syncProduce()
}

func syncProduce() {
	arr := strings.Split(*kafkaServer, ",")

	producer, err := sarama.NewSyncProducer(arr, nil)
	if err != nil {
		log.Fatalln(err)
	}
	defer func() {
		if err := producer.Close(); err != nil {
			log.Fatalln(err)
		}
	}()

	b := time.Now()
	for i := int64(0); i < *count; i++ {
		msg := &sarama.ProducerMessage{
			Topic: *topic,
			Value: sarama.StringEncoder(fmt.Sprintf("t%d", i)),
		}

		partition, offset, err := producer.SendMessage(msg)

		if err != nil {
			log.Printf("FAILED to send message: %s\n", err)
		} else {
			if offset%10000 == 0 {
				log.Printf("> message sent to partition %d at offset %d\n", partition, offset)
			}
		}
	}
	elapsed := time.Since(b)
	log.Printf("> elapsed: %v,  %v\n", elapsed, *count)

}
