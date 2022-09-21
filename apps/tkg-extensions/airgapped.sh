#!/bin/bash

export HARBOR_EXTERNAL="projects.registry.vmware.com"
export HARBOR_INTERNAL="harbor.dorn.gorke.ml"
export CA_1="-----BEGIN CERTIFICATE-----
MIIC/jCCAeagAwIBAgIBADANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQDEwprdWJl
..
tfM=
-----END CERTIFICATE-----"


#################################### tkg-extensions-templates ######################################################
export TKG_EXTENSION_1="${HARBOR_EXTERNAL}/tkg/tkg-extensions-templates:v1.3.1_vmware.1"
export TKG_EXTENSION_INTERNAL="${HARBOR_INTERNAL}/tkg/tkg-extensions-templates:v1.3.1_vmware.1"

docker pull $TKG_EXTENSION_1
docker tag $TKG_EXTENSION_1 $TKG_EXTENSION_INTERNAL
docker push $TKG_EXTENSION_INTERNAL

#################################### cert-manager ######################################################
export CM_1="${HARBOR_EXTERNAL}/tkg/cert-manager/cert-manager-cainjector:v0.16.1_vmware.1"
export CM_2="${HARBOR_EXTERNAL}/tkg/cert-manager/cert-manager-controller:v0.16.1_vmware.1"
export CM_3="${HARBOR_EXTERNAL}/tkg/cert-manager/cert-manager-webhook:v0.16.1_vmware.1"

export CM_1_INTERNAL="${HARBOR_INTERNAL}/tkg/cert-manager/cert-manager-cainjector:v0.16.1_vmware.1"
export CM_2_INTERNAL="${HARBOR_INTERNAL}/tkg/cert-manager/cert-manager-controller:v0.16.1_vmware.1"
export CM_3_INTERNAL="${HARBOR_INTERNAL}/tkg/cert-manager/cert-manager-webhook:v0.16.1_vmware.1"

docker pull $CM_1
docker tag $CM_1 $CM_1_INTERNAL
docker push $CM_1_INTERNAL
docker pull $CM_2
docker tag $CM_2 $CM_2_INTERNAL
docker push $CM_2_INTERNAL
docker pull $CM_3
docker tag $CM_3 $CM_3_INTERNAL
docker push $CM_3_INTERNAL

sed -i -e "s~$CM_1~$CM_1_INTERNAL~g" ./01-cert-manager/03-cert-manager.yaml
sed -i -e "s~$CM_2~$CM_2_INTERNAL~g" ./01-cert-manager/03-cert-manager.yaml
sed -i -e "s~$CM_3~$CM_3_INTERNAL~g" ./01-cert-manager/03-cert-manager.yaml

#kubectl apply -f ./01-cert-manager/

#################################### kapp-controller ######################################################
export KAP_1="${HARBOR_EXTERNAL}/tkg/kapp-controller:v0.18.0_vmware.1"
export KAP_1_INTERNAL="${HARBOR_INTERNAL}/tkg/kapp-controller:v0.18.0_vmware.1"

docker pull $KAP_1
docker tag $KAP_1 $KAP_1_INTERNAL
docker push $KAP_1_INTERNAL

sed -i -e "s~$KAP_1~$KAP_1_INTERNAL~g" ./02-kapp-controller/kapp-controller.yaml

yq -i '.data.caCerts = strenv(CA_1)' 02-kapp-controller/kapp-controller-config.yaml

#kubectl apply -f ./02-kapp-controller/


#################################### contour ######################################################

export CONTOUR_1="${HARBOR_EXTERNAL}/tkg/contour:v1.12.0_vmware.1"
export CONTOUR_2="${HARBOR_EXTERNAL}/tkg/envoy:v1.17.0_vmware.1"

export CONTOUR_1_INTERNAL="${HARBOR_INTERNAL}/tkg/contour:v1.12.0_vmware.1"
export CONTOUR_2_INTERNAL="${HARBOR_INTERNAL}/tkg/envoy:v1.17.0_vmware.1"

docker pull $CONTOUR_1
docker tag $CONTOUR_1 $CONTOUR_1_INTERNAL
docker push $CONTOUR_1_INTERNAL

docker pull $CONTOUR_2
docker tag $CONTOUR_2 $CONTOUR_2_INTERNAL
docker push $CONTOUR_2_INTERNAL

sed -i -e "s~$HARBOR_EXTERNAL~$HARBOR_INTERNAL~g" ./03-contour/overlay/overlay-vsphere.yaml
sed -i -e "s~$HARBOR_EXTERNAL~$HARBOR_INTERNAL~g" ./03-contour/contour.yaml
export CONTOUR_OVERLAY=$(cat ./03-contour/overlay/overlay-vsphere.yaml|base64)

echo $CONTOUR_OVERLAY

export CONTOUR="CHANGEMEBASE64"
sed -i -e "s~$CONTOUR~$CONTOUR_OVERLAY~g" ./03-contour/contour.yaml

#kubectl apply -f 03-contour/contour.yaml

#################################### prometheus ######################################################

export PROMETHEUS_1="${HARBOR_EXTERNAL}/tkg/prometheus/alertmanager:v0.20.0_vmware.1"
export PROMETHEUS_2="${HARBOR_EXTERNAL}/tkg/prometheus/configmap-reload:v0.3.0_vmware.1"
export PROMETHEUS_3="${HARBOR_EXTERNAL}/tkg/prometheus/cadvisor:v0.36.0_vmware.1"
export PROMETHEUS_4="${HARBOR_EXTERNAL}/tkg/prometheus/kube-state-metrics:v1.9.5_vmware.2"
export PROMETHEUS_5="${HARBOR_EXTERNAL}/tkg/prometheus/prometheus_node_exporter:v0.18.1_vmware.1"
export PROMETHEUS_6="${HARBOR_EXTERNAL}/tkg/prometheus/pushgateway:v1.2.0_vmware.2"
export PROMETHEUS_7="${HARBOR_EXTERNAL}/tkg/prometheus/cadvisor:v0.36.0_vmware.1"
export PROMETHEUS_8="${HARBOR_EXTERNAL}/tkg/prometheus/configmap-reload:v0.3.0_vmware.1"
export PROMETHEUS_9="${HARBOR_EXTERNAL}/tkg/prometheus/prometheus:v2.18.1_vmware.1"

export PROMETHEUS_1_INTERNAL="${HARBOR_INTERNAL}/tkg/prometheus/alertmanager:v0.20.0_vmware.1"
export PROMETHEUS_2_INTERNAL="${HARBOR_INTERNAL}/tkg/prometheus/configmap-reload:v0.3.0_vmware.1"
export PROMETHEUS_3_INTERNAL="${HARBOR_INTERNAL}/tkg/prometheus/cadvisor:v0.36.0_vmware.1"
export PROMETHEUS_4_INTERNAL="${HARBOR_INTERNAL}/tkg/prometheus/kube-state-metrics:v1.9.5_vmware.2"
export PROMETHEUS_5_INTERNAL="${HARBOR_INTERNAL}/tkg/prometheus/prometheus_node_exporter:v0.18.1_vmware.1"
export PROMETHEUS_6_INTERNAL="${HARBOR_INTERNAL}/tkg/prometheus/pushgateway:v1.2.0_vmware.2"
export PROMETHEUS_7_INTERNAL="${HARBOR_INTERNAL}/tkg/prometheus/cadvisor:v0.36.0_vmware.1"
export PROMETHEUS_8_INTERNAL="${HARBOR_INTERNAL}/tkg/prometheus/configmap-reload:v0.3.0_vmware.1"
export PROMETHEUS_9_INTERNAL="${HARBOR_INTERNAL}/tkg/prometheus/prometheus:v2.18.1_vmware.1"

docker pull $PROMETHEUS_1
docker tag $PROMETHEUS_1 $PROMETHEUS_1_INTERNAL
docker push $PROMETHEUS_1_INTERNAL
docker pull $PROMETHEUS_2
docker tag $PROMETHEUS_2 $PROMETHEUS_2_INTERNAL
docker push $PROMETHEUS_2_INTERNAL
docker pull $PROMETHEUS_3
docker tag $PROMETHEUS_3 $PROMETHEUS_3_INTERNAL
docker push $PROMETHEUS_3_INTERNAL
docker pull $PROMETHEUS_4
docker tag $PROMETHEUS_4 $PROMETHEUS_4_INTERNAL
docker push $PROMETHEUS_4_INTERNAL
docker pull $PROMETHEUS_5
docker tag $PROMETHEUS_5 $PROMETHEUS_5_INTERNAL
docker push $PROMETHEUS_5_INTERNAL
docker pull $PROMETHEUS_6
docker tag $PROMETHEUS_6 $PROMETHEUS_6_INTERNAL
docker push $PROMETHEUS_6_INTERNAL
docker pull $PROMETHEUS_7
docker tag $PROMETHEUS_7 $PROMETHEUS_7_INTERNAL
docker push $PROMETHEUS_7_INTERNAL
docker pull $PROMETHEUS_8
docker tag $PROMETHEUS_8 $PROMETHEUS_8_INTERNAL
docker push $PROMETHEUS_8_INTERNAL
docker pull $PROMETHEUS_9
docker tag $PROMETHEUS_9 $PROMETHEUS_9_INTERNAL
docker push $PROMETHEUS_9_INTERNAL


sed -i -e "s~$HARBOR_EXTERNAL~$HARBOR_INTERNAL~g" ./04-prometheus/overlay/overlay.yaml
sed -i -e "s~$HARBOR_EXTERNAL~$HARBOR_INTERNAL~g" ./04-prometheus/prometheus.yaml
export PROMETHEUS_OVERLAY=$(cat ./03-contour/overlay/overlay-vsphere.yaml|base64)

export PROMETHEUS="CHANGEMEBASE64"
sed -i -e "s~$PROMETHEUS~$PROMETHEUS_OVERLAY~g" ./04-prometheus/prometheus.yaml

#kubectl apply -f 04-prometheus/prometheus.yaml