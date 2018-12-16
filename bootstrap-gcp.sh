#!/bin/bash

echo "installing helm tiller and client"
bash ./setup-gcp.sh

echo "default installation storageClass and role binding for dashboard admin"
bash ./setup-gcp.sh --chart charts/default
#
# echo "installing nginx-ingress"
# bash ./setup-gcp.sh --chart charts/nginx-ingress
#
# echo "installing elasticsearch"
# bash ./setup-gcp.sh --chart charts/elasticsearch
#
# echo "installing filebeat"
# bash ./setup-gcp.sh --chart charts/filebeat

#echo "installing logstash"
#bash  ./setup-gcp.sh --chart charts/logstash
#
# echo "installing nifi"
#  bash ./setup-gcp.sh --chart charts/apache-nifi

#echo "installing Prometheus"
# bash ./setup-gcp.sh --chart charts/prometheus

#echo "installing Grafana"
# bash ./setup-gcp.sh --chart charts/grafana
#
# echo "installing Influxdb"
#  bash ./setup-gcp.sh --chart charts/influxdb

#echo "installing kafka"
#bash ./setup-gcp.sh --chart charts/kafka

#echo "installing ksql"
#bash ./setup-gcp.sh --chart charts/ksql

echo "installing node-red"
bash ./setup-gcp.sh --chart charts/node-red
