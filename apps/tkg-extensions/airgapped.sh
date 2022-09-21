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

sed -i -e "s~$HARBOR_EXTERNAL~$HARBOR_INTERNAL~g" ./03-contour/overlay/overlay-vsphere.yaml

export CONTOUR_OVERLAY=$(cat ./03-contour/overlay/overlay-vsphere.yaml|base64)

echo $CONTOUR_OVERLAY

export CONTOUR="CHANGEMEBASE64"
sed -i -e "s~$CONTOUR~$CONTOUR_OVERLAY~g" ./03-contour/01-namespace-role.yaml

#kubectl apply -f 03-contour/01-namespace-role.yaml