#!/bin/bash

export HARBOR_EXTERNAL="projects.registry.vmware.com"
export HARBOR_INTERNAL="harbor.mgt.mytanzu.org"
export HARBOR_FQDN="harbor.corp.com"
export CA_INTERNAL="-----BEGIN CERTIFICATE-----
MIIC/jCCAeagAwIBAgIBADANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQDEwprdWJl
..
tfM=
-----END CERTIFICATE-----"
export HARBOR_TLS_CRT="-----BEGIN CERTIFICATE-----
MIIC/jCCAeagAwIBAgIBADANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQDEwprdWJl
..
tfM=
-----END CERTIFICATE-----"
export HARBOR_TLS_KEY="-----BEGIN CERTIFICATE-----
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

#################################### kapp-controller ######################################################
export KAP_1="${HARBOR_EXTERNAL}/tkg/kapp-controller:v0.18.0_vmware.1"
export KAP_1_INTERNAL="${HARBOR_INTERNAL}/tkg/kapp-controller:v0.18.0_vmware.1"

docker pull $KAP_1
docker tag $KAP_1 $KAP_1_INTERNAL
docker push $KAP_1_INTERNAL

yq -i '.data.caCerts = strenv(CA_INTERNAL)' 02-kapp-controller/kapp-controller-config.yaml

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

#################################### grafana######################################################

export GRAFANA_1="${HARBOR_EXTERNAL}/tkg/grafana/grafana:v7.3.5_vmware.2"
export GRAFANA_2="${HARBOR_EXTERNAL}/tkg/grafana/k8s-sidecar:v0.1.144_vmware.2"

export GRAFANA_1_INTERNAL="${HARBOR_INTERNAL}/tkg/grafana/grafana:v7.3.5_vmware.2"
export GRAFANA_2_INTERNAL="${HARBOR_INTERNAL}/tkg/grafana/k8s-sidecar:v0.1.144_vmware.2"

docker pull $GRAFANA_1
docker tag $GRAFANA_1 $GRAFANA_1_INTERNAL
docker push $GRAFANA_1_INTERNAL
docker pull $GRAFANA_2
docker tag $GRAFANA_2 $GRAFANA_2_INTERNAL
docker push $GRAFANA_2_INTERNAL

#################################### EFK ######################################################
export EFK_1="docker.io/bitnami/bitnami-shell:10-debian-10-r138"
export EFK_2="docker.io/bitnami/elasticsearch:7.2.1"
export EFK_3="projects.registry.vmware.com/tkg/fluent-bit:v1.6.9_vmware.1"
export EFK_4="docker.io/bitnami/kibana:7.2.1"
export EKF_D="docker.io/bitnami"

export EFK_1_INTERNAL="${HARBOR_INTERNAL}/tkg/bitnami-shell:10-debian-10-r138"
export EFK_2_INTERNAL="${HARBOR_INTERNAL}/tkg/elasticsearch:7.2.1"
export EFK_3_INTERNAL="${HARBOR_INTERNAL}/tkg/fluent-bit:v1.6.9_vmware.1"
export EFK_4_INTERNAL="${HARBOR_INTERNAL}/tkg/kibana:7.2.1"

docker pull $EFK_1
docker tag $EFK_1 $EFK_1_INTERNAL
docker push $EFK_1_INTERNAL
docker pull $EFK_2
docker tag $EFK_2 $EFK_2_INTERNAL
docker push $EFK_2_INTERNAL
docker pull $EFK_3
docker tag $EFK_3 $EFK_3_INTERNAL
docker push $EFK_3_INTERNAL
docker pull $EFK_4
docker tag $EFK_4 $EFK_4_INTERNAL
docker push $EFK_4_INTERNAL


#################################### Harbor ######################################################

export HARBOR_2="${HARBOR_EXTERNAL}/tkg/harbor/clair-adapter-photon:v2.1.3_vmware.1"
export HARBOR_1="${HARBOR_EXTERNAL}/tkg/harbor/clair-photon:v2.1.3_vmware.1"
export HARBOR_3="${HARBOR_EXTERNAL}/tkg/harbor/harbor-core:v2.1.3_vmware.1"
export HARBOR_4="${HARBOR_EXTERNAL}/tkg/harbor/harbor-db:v2.1.3_vmware.1"
export HARBOR_5="${HARBOR_EXTERNAL}/tkg/harbor/harbor-jobservice:v2.1.3_vmware.1"
export HARBOR_6="${HARBOR_EXTERNAL}/tkg/harbor/notary-server-photon:v2.1.3_vmware.1"
export HARBOR_7="${HARBOR_EXTERNAL}/tkg/harbor/notary-signer-photon:v2.1.3_vmware.1"
export HARBOR_8="${HARBOR_EXTERNAL}/tkg/harbor/harbor-portal:v2.1.3_vmware.1"
export HARBOR_9="${HARBOR_EXTERNAL}/tkg/harbor/redis-photon:v2.1.3_vmware.1"
export HARBOR_10="${HARBOR_EXTERNAL}/tkg/harbor/registry-photon:v2.1.3_vmware.1"
export HARBOR_11="${HARBOR_EXTERNAL}/tkg/harbor/harbor-registryctl:v2.1.3_vmware.1"
export HARBOR_12="${HARBOR_EXTERNAL}/tkg/harbor/trivy-adapter-photon:v2.1.3_vmware.1"

export HARBOR_1_INTERNAL="${HARBOR_INTERNAL}/tkg/harbor/clair-photon:v2.1.3_vmware.1"
export HARBOR_2_INTERNAL="${HARBOR_INTERNAL}/tkg/harbor/clair-adapter-photon:v2.1.3_vmware.1"
export HARBOR_3_INTERNAL="${HARBOR_INTERNAL}/tkg/harbor/harbor-core:v2.1.3_vmware.1"
export HARBOR_4_INTERNAL="${HARBOR_INTERNAL}/tkg/harbor/harbor-db:v2.1.3_vmware.1"
export HARBOR_5_INTERNAL="${HARBOR_INTERNAL}/tkg/harbor/harbor-jobservice:v2.1.3_vmware.1"
export HARBOR_6_INTERNAL="${HARBOR_INTERNAL}/tkg/harbor/notary-server-photon:v2.1.3_vmware.1"
export HARBOR_7_INTERNAL="${HARBOR_INTERNAL}/tkg/harbor/notary-signer-photon:v2.1.3_vmware.1"
export HARBOR_8_INTERNAL="${HARBOR_INTERNAL}/tkg/harbor/harbor-portal:v2.1.3_vmware.1"
export HARBOR_9_INTERNAL="${HARBOR_INTERNAL}/tkg/harbor/redis-photon:v2.1.3_vmware.1"
export HARBOR_10_INTERNAL="${HARBOR_INTERNAL}/tkg/harbor/registry-photon:v2.1.3_vmware.1"
export HARBOR_11_INTERNAL="${HARBOR_INTERNAL}/tkg/harbor/harbor-registryctl:v2.1.3_vmware.1"
export HARBOR_12_INTERNAL="${HARBOR_INTERNAL}/tkg/harbor/trivy-adapter-photon:v2.1.3_vmware.1"

docker pull $HARBOR_1
docker tag $HARBOR_1 $HARBOR_1_INTERNAL
docker push $HARBOR_1_INTERNAL
docker pull $HARBOR_2
docker tag $HARBOR_2 $HARBOR_2_INTERNAL
docker push $HARBOR_2_INTERNAL
docker pull $HARBOR_3
docker tag $HARBOR_3 $HARBOR_3_INTERNAL
docker push $HARBOR_3_INTERNAL
docker pull $HARBOR_4
docker tag $HARBOR_4 $HARBOR_4_INTERNAL
docker push $HARBOR_4_INTERNAL
docker pull $HARBOR_5
docker tag $HARBOR_5 $HARBOR_5_INTERNAL
docker push $HARBOR_5_INTERNAL
docker pull $HARBOR_6
docker tag $HARBOR_6 $HARBOR_6_INTERNAL
docker push $HARBOR_6_INTERNAL
docker pull $HARBOR_7
docker tag $HARBOR_7 $HARBOR_7_INTERNAL
docker push $HARBOR_7_INTERNAL
docker pull $HARBOR_8
docker tag $HARBOR_8 $HARBOR_8_INTERNAL
docker push $HARBOR_8_INTERNAL
docker pull $HARBOR_9
docker tag $HARBOR_9 $HARBOR_9_INTERNAL
docker push $HARBOR_9_INTERNAL
docker pull $HARBOR_10
docker tag $HARBOR_10 $HARBOR_10_INTERNAL
docker push $HARBOR_10_INTERNAL
docker pull $HARBOR_11
docker tag $HARBOR_11 $HARBOR_11_INTERNAL
docker push $HARBOR_11_INTERNAL
docker pull $HARBOR_12
docker tag $HARBOR_12 $HARBOR_12_INTERNAL
docker push $HARBOR_12_INTERNAL

