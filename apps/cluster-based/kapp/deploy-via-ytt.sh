#!/bin/bash

kubectl apply -f 01-cert-manager/
kubectl apply -f 02-kapp-controller/
ytt --ignore-unknown-comments -f ./03-ytt/03-contour/contour.yaml -f ./values.yaml|kubectl apply -f -
ytt --ignore-unknown-comments -f ./03-ytt/04-prometheus/prometheus.yaml -f ./values.yaml|kubectl apply -f -
ytt --ignore-unknown-comments -f ./03-ytt/05-grafana/grafana.yaml -f ./values.yaml|kubectl apply -f -
ytt --ignore-unknown-comments -f ./03-ytt/06-efk/efk.yaml -f ./values.yaml|kubectl apply -f -
ytt --ignore-unknown-comments -f ./03-ytt/07-harbor/harbor.yaml -f ./values.yaml|kubectl apply -f -