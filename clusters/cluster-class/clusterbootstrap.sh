#!/bin/bash

kubectx supervisor
kubectl -n dev patch clusterbootstrap cc-06 --type='json' -p='[{"op": "add", "path": "/spec/additionalPackages/-", "value": {"refName": "cert-manager.tanzu.vmware.com.1.7.2+vmware.3-tkg.1"}}]'

cat <<EOF | kubectl apply -f -
---
apiVersion: v1
stringData:
  values.yaml: |-
    ---
    infrastructure_provider: vsphere
    namespace: tanzu-system-ingress
    contour:
     configFileContents: {}
     useProxyProtocol: false
     replicas: 2
     pspNames: "vmware-system-restricted"
     logLevel: warn
    envoy:
     service:
       type: LoadBalancer
       annotations: {}
       nodePorts:
         http: null
         https: null
       externalTrafficPolicy: Cluster
       disableWait: false
     hostPorts:
       enable: true
       http: 80
       https: 443
     hostNetwork: false
     terminationGracePeriodSeconds: 300
     logLevel: info
     pspNames: null
    certificates:
     duration: 8760h
     renewBefore: 360h
kind: Secret
metadata:
  creationTimestamp: null
  name: cc-06-contour-data-values
  namespace: dev
EOF

kubectl label secret cc-06-contour-data-values -n dev "tkg.tanzu.vmware.com/cluster-name=cc-06"

kubectl -n dev patch clusterbootstrap cc-06 --type='json' -p='[{"op": "add", "path": "/spec/additionalPackages/-", "value": {"refName": "contour.tanzu.vmware.com.1.22.3+vmware.1-tkg.1", "valuesFrom": {"secretRef": "cc-06-contour-data-values"}}}]'
