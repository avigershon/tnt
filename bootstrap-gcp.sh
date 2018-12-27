#!/bin/bash

echo "installing helm tiller and client"
bash ./setup-gcp.sh

echo "Create Pub/Sub secret key"
kubectl create secret generic pubsub-key --from-file=key.json=../../kube-pubsub-publisher.json

echo "default installation storageClass and role binding for dashboard admin"
bash ./setup-gcp.sh --chart charts/default

helm install --name nginx-ingress stable/nginx-ingress --namespace kube-system --set controller.hostNetwork=true,controller.kind=DaemonSet

#helm install --name kube-lego stable/kube-lego --namespace kube-system --set config.LEGO_EMAIL=avigershon@gmail.com,config.LEGO_URL=https://acme-v01.api.letsencrypt.org/directory

helm install --name cert-manager stable/cert-manager --set createCustomResource=false

helm upgrade --install cert-manager stable/cert-manager --set createCustomResource=true --set ingressShim.extraArgs='{--default-issuer-name=letsencrypt-prod,--default-issuer-kind=ClusterIssuer}'

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
