#!/bin/bash

# argo-cd needs to be deployed first on shared cluster
# don't forget to update overlay.yaml and use base64 value of it.
# don't forget to add wildcard A Record on DNS for each cluster

#on shared services cluster

kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: argo-cd
  name: argocd-robot
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: argocd-robot-clusterrolebinding
subjects:
  - kind: ServiceAccount
    name: argocd-robot
    namespace: argo-cd
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: ""
EOF

export token=$(kubectl -n argo-cd get serviceaccounts argocd-robot -o json | jq -r '.secrets[] .name' | xargs -I {} sh -c "kubectl -n argo-cd get secret -o json {} | jq -r '.data .token'" | base64 -d)
export ca=$(kubectl -n argo-cd get serviceaccounts argocd-robot -o json | jq -r '.secrets[] .name' | xargs -I {} sh -c "kubectl -n argo-cd get secret {} -o jsonpath='{.data.ca\.crt}'")


kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: incluster
  namespace: argo-cd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: incluster
  server: https://kubernetes.default.svc
  config: |
    {
      "bearerToken": "${token}",
      "tlsClientConfig": {
        "serverName": "https://kubernetes.default.svc",
        "ca": "${ca}"
      }
    }
EOF


kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: shared-cluster-baseline-apps
  namespace: argo-cd
  annotations:
    argocd.argoproj.io/sync-wave: "0"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/gorkemozlu/tanzu-gitops.git
    targetRevision: HEAD
    path: apps/cluster-based/shared
    directory:
      recurse: true
  destination:
    server: "https://kubernetes.default.svc"
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - ServerSideApply=true
EOF


#on dev cluster
kubectx dev-cluster

kubectl create ns argo-cd
kubectl apply -f - <<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: argo-cd
  name: argocd-robot
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: argocd-robot-clusterrolebinding
subjects:
  - kind: ServiceAccount
    name: argocd-robot
    namespace: argo-cd
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: ""
EOF
export token=$(kubectl -n argo-cd get serviceaccounts argocd-robot -o json | jq -r '.secrets[] .name' | xargs -I {} sh -c "kubectl -n argo-cd get secret -o json {} | jq -r '.data .token'" | base64 -d)
export ca=$(kubectl -n argo-cd get serviceaccounts argocd-robot -o json | jq -r '.secrets[] .name' | xargs -I {} sh -c "kubectl -n argo-cd get secret {} -o jsonpath='{.data.ca\.crt}'")
export MASTER_VIP=$(kubectl config get-contexts|grep "$(echo $(kubectl config current-context))"|awk '{print $3}')


#on shared cluster
kubectx shared-cluster

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: dev-cluster
  namespace: argo-cd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: dev-cluster
  server: "https://${MASTER_VIP}:6443"
  config: |
    {
      "bearerToken": "${token}",
      "tlsClientConfig": {
        "serverName": "https://${MASTER_VIP}:6443",
        "insecure": true,
        "ca": "${ca}"
      }
    }
EOF



kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dev-cluster-baseline-apps
  namespace: argo-cd
  annotations:
    argocd.argoproj.io/sync-wave: "0"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/gorkemozlu/tanzu-gitops.git
    targetRevision: HEAD
    path: apps/cluster-based/dev
    directory:
      recurse: true
  destination:
    server: "https://${MASTER_VIP}:6443"
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - ServerSideApply=true
EOF