#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 vsphere-7|vsphere8"
    exit 1
fi

export wcp_ip=$(yq eval '.wcp.ip' ./values.yaml)
export wcp_user=$(yq eval '.wcp.ip' ./values.yaml)
export wcp_pass=$(yq eval '.wcp.ip' ./values.yaml)
export namespace=$(yq eval '.shared_cluster.namespace' ./values.yaml)
export tmc_cluster='shared'
export ldap_auth=$(yq eval '.auth.ldap.enabled' ./values.yaml)

cp ca.crt /etc/ssl/certs/

if [ "$1" = "vsphere-7" ]; then
    echo vsphere-7
    export KUBECTL_VSPHERE_PASSWORD=$wcp_pass
    kubectl vsphere login --server=$wcp_ip --vsphere-username $wcp_user --insecure-skip-tls-verify
    kubectx $wcp_ip
    export CA_CERT=$(cat ./ca.crt|base64 -w0)
    kubectl patch TkgServiceConfiguration tkg-service-configuration --type merge -p '{"spec":{"trust":{"additionalTrustedCAs":[{"name":"root-ca-tmc","data":"'$(echo -n "$CA_CERT")'"}]}}}'
    kubectl apply -f templates/vsphere-7/shared.yaml
    while [[ $(kubectl get cluster shared -o=jsonpath='{.status.conditions[?(@.type=="Ready")].status}' -n $namespace) != "True" ]]; do
        echo "waiting for cluster to be ready"
        sleep 30
    done
    kubectl vsphere login --server=$wcp_ip --tanzu-kubernetes-cluster-name shared --tanzu-kubernetes-cluster-namespace $namespace --vsphere-username $wcp_user --insecure-skip-tls-verify
    kubectx $tmc_cluster
    kubectl create clusterrolebinding default-tkg-admin-privileged-binding --clusterrole=psp:vmware-system-privileged --group=system:authenticated
    ytt -f templates/common/kapp-controller.yaml -f templates/values-template.yaml | kubectl apply -f -
    while [[ $(kubectl get deployment kapp-controller -n tkg-system -o=jsonpath='{.status.conditions[?(@.type=="Available")].status}') != "True" ]]; do
        echo "waiting for kapp-controller to be ready"
        sleep 10
    done
elif [ "$1" = "vsphere-8" ]; then
    echo vsphere-8
    export KUBECTL_VSPHERE_PASSWORD=$wcp_pass
    kubectl vsphere login --server=$wcp_ip --vsphere-username $wcp_user --insecure-skip-tls-verify
    kubectx $wcp_ip
    ytt -f templates/values-template.yaml -f templates/vsphere-8/shared-cluster.yaml | kubectl apply -f -
    while [[ $(kubectl get cluster shared -o=jsonpath='{.status.conditions[?(@.type=="Ready")].status}' -n $namespace) != "True" ]]; do
        echo "waiting for cluster to be ready"
        sleep 30
    done
    kubectl vsphere login --server=$wcp_ip --tanzu-kubernetes-cluster-name shared --tanzu-kubernetes-cluster-namespace $namespace --vsphere-username $wcp_user --insecure-skip-tls-verify
    kubectx $tmc_cluster
    kubectl create clusterrolebinding default-tkg-admin-privileged-binding --clusterrole=psp:vmware-system-privileged --group=system:authenticated
fi

kubectx $tmc_cluster
ytt -f templates/common/std-repo.yaml -f templates/values-template.yaml | kubectl apply -f -
while [[ $(kubectl get pkgr tanzu-std-repo -n packages -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; do
    echo "waiting for std-repo to be ready"
    sleep 10
done
ytt -f templates/common/cert-manager.yaml -f templates/values-template.yaml | kubectl apply -f -
while [[ $(kubectl get pkgi cert-manager -n packages -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; do
    echo "waiting for cert-manager to be ready"
    sleep 10
done
kubectl create secret tls local-ca --key ca-no-pass.key --cert ca.crt -n cert-manager
kubectl apply -f templates/common/local-issuer.yaml
ytt -f templates/values-template.yaml -f templates/common/tmc-values-template.yaml > values.yaml
ytt -f templates/values-template.yaml -f templates/common/tmc-repo.yaml | kubectl apply -f -
while [[ $(kubectl get pkgr tanzu-mission-control-packages -n tmc-local -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; do
    echo "waiting for tmc-repo to be ready"
    sleep 10
done
if [ "$ldap_auth" = "true" ]; then
    kubectl apply -f templates/common/openldap.yaml
    kubectl apply -f templates/common/ldap-overlay.yaml
    while [[ ${#openldapCaCert} -gt 3 ]]; do
        echo "waiting for openldap to be ready"
        export openldapCaCert=$(kubectl get secret ldap -n openldap -o json | jq -r '.data."ca.crt"')
        sleep 10
    done
    ytt -f  templates/common/ldap-auth.yaml --data-value ldapCa=$openldapCaCert | kubectl apply -f -
fi
export valuesContent=$(cat values.yaml)
ytt -f templates/values-template.yaml --data-value valuesContent=$valuesContent -f templates/common/tmc-install.yaml | kubectl apply -f -



kubectx $wcp_ip
export caCert=$(yq eval '.trustedCAs."custom-ca.pem"' ./values.yaml)
export tmcURL=$(yq eval '.dnsZone' ./values.yaml)
export tmcNS=$(kubectl get ns|grep svc-tmc|awk '{ print $1 }')
yq e -i ".spec.caCerts = strenv(caCert)" ./templates/common/agentconfig.yaml
yq e -i ".spec.allowedHostNames = [env(tmcURL)]" ./templates/common/agentconfig.yaml
yq e -i ".metadata.namespace = strenv(tmcNS)" ./templates/common/agentconfig.yaml

kubectl apply -f ./templates/common/agentconfig.yaml