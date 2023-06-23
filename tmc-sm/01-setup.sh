#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 vsphere-7|vsphere-8"
    exit 1
fi

if [ -f ca.crt ] && [ -f ca-no-pass.key ]; then
    echo "required files exist, continuing."
else
    export CA_CERT=$(yq eval '.trustedCAs.ca' ./templates/values-template.yaml)
    export CA_KEY=$(yq eval '.trustedCAs.key' ./templates/values-template.yaml)
    echo "$CA_CERT" > ./ca.crt
    echo "$CA_KEY" > ./ca-no-pass.crt
    if [ -s ca.crt ] && [ -s ca-no-pass.key ]; then
        echo "ca.crt and ca-no-pass.crt files created."
    else
        echo "The file is empty or does not exist."
        echo "check ca.crt and/or ca-no-pass.key"
        echo "check ./templates/values-template.yaml file for CA Cert and Key"
        exit 1
    fi
fi

export GOVC_URL=$(yq eval '.vcenter.fqdn' ./templates/values-template.yaml)
export GOVC_INSECURE=1

export vCenter_version=$(govc about|grep Version|awk '{ print $2 }')
export vCenter_build=$(govc about|grep Build|awk '{ print $2 }')

if [[ "$vCenter_version" == "7.0.3" ]]; then
    if [[ $vCenter_build -le "21477706" ]]; then
        echo "vCenter version: " "$vCenter_version "/ Build" $vCenter_build, upgrade vCenter. Exiting"
        exit 1
    fi
elif [[ "$vCenter_version" == "8.0.1" ]]; then
    if [[ $vCenter_build -le "21457384" ]]; then
        echo "vCenter version: " "$vCenter_version "/ Build" $vCenter_build, upgrade vCenter. Exiting"
        exit 1
    fi
else
    echo "wrong vcenter build/version. Exiting"
    exit 1
fi

export wcp_ip=$(yq eval '.wcp.ip' ./templates/values-template.yaml)
export wcp_user=$(yq eval '.wcp.user' ./templates/values-template.yaml)
export wcp_pass=$(yq eval '.wcp.password' ./templates/values-template.yaml)
export namespace=$(yq eval '.shared_cluster.namespace' ./templates/values-template.yaml)
export tmc_cluster='shared'
export ldap_auth=$(yq eval '.auth.ldap.enabled' ./templates/values-template.yaml)
export tmc_dns=$(yq eval '.tld_domain' ./templates/values-template.yaml)
export hostnames=($tmc_dns *.$tmc_dns)

for hostname in "${hostnames[@]}"; do
    output=$(dig +short "$hostname")
    if [[ -n "$output" ]]; then
        echo "DNS A record is resolvable for $hostname"
    else
        echo "DNS A record is not resolvable for $hostname"
        exit 1
    fi
done

cp ca.crt /etc/ssl/certs/

if [ "$1" = "vsphere-7" ]; then
    echo vsphere-7
    export KUBECTL_VSPHERE_PASSWORD=$wcp_pass
    kubectl vsphere login --server=$wcp_ip --vsphere-username $wcp_user --insecure-skip-tls-verify
    kubectx $wcp_ip
    export CA_CERT=$(cat ./ca.crt|base64 -w0)
    kubectl patch TkgServiceConfiguration tkg-service-configuration --type merge -p '{"spec":{"trust":{"additionalTrustedCAs":[{"name":"root-ca-tmc","data":"'$(echo -n "$CA_CERT")'"}]}}}'
    ytt -f templates/values-template.yaml -f templates/vsphere-7/shared-cluster.yaml | kubectl apply -f -
    while [[ $(kubectl get tkc shared -o=jsonpath='{.status.conditions[?(@.type=="Ready")].status}' -n $namespace) != "True" ]]; do
        echo "waiting for cluster to be ready"
        sleep 30
    done
    kubectl vsphere login --server=$wcp_ip --tanzu-kubernetes-cluster-name shared --tanzu-kubernetes-cluster-namespace $namespace --vsphere-username $wcp_user --insecure-skip-tls-verify
    kubectx $tmc_cluster
    kubectl create clusterrolebinding default-tkg-admin-privileged-binding --clusterrole=psp:vmware-system-privileged --group=system:authenticated
    ytt -f templates/common/kapp-controller.yaml -f templates/values-template.yaml | kubectl apply -f -
    while [[ $(kubectl get deployment kapp-controller -n kapp-controller -o=jsonpath='{.status.conditions[?(@.type=="Available")].status}') != "True" ]]; do
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
    export node_names=$(kubectl get nodes -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
    while [[ -z "$node_names" ]]; do
        node_names=$(kubectl get nodes -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
        if [[ -z "$node_names" ]]; then
            echo "waiting for cluster to be ready"
            sleep 30
        fi
    done
    kubectl create clusterrolebinding default-tkg-admin-privileged-binding --clusterrole=psp:vmware-system-privileged --group=system:authenticated
fi

kubectx $tmc_cluster
ytt -f templates/common/std-repo.yaml -f templates/values-template.yaml | kubectl apply -f -
while [[ $(kubectl get pkgr tanzu-std-repo -n packages -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; do
    echo "waiting for std-repo to be ready"
    sleep 10
    if [[ $(kubectl get pkgr tanzu-std-repo -n packages -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') == "ReconcileFailed" ]]; then
        kubectl get pkgr tanzu-std-repo -n packages -o=jsonpath='{.status.usefulErrorMessage}'
        ytt -f templates/common/std-repo.yaml -f templates/values-template.yaml | kubectl delete -f -
        sleep 5
        ytt -f templates/common/std-repo.yaml -f templates/values-template.yaml | kubectl apply -f -
    fi
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

export valuesContent=$(cat values.yaml)
ytt -f templates/values-template.yaml --data-value valuesContent="$valuesContent" -f templates/common/tmc-install.yaml | kubectl apply -f -
while [[ $(kubectl get pkgi tanzu-mission-control -n tmc-local -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; do
    echo "waiting for tanzu-mission-control to be ready"
    sleep 10
done
if [ "$ldap_auth" = "true" ]; then
   ytt -f templates/values-template.yaml -f templates/common/openldap.yaml | kubectl apply -f -
    kubectl apply -f templates/common/ldap-overlay.yaml
    while [[ $(kubectl get deployment openldap -n openldap -o=jsonpath='{.status.conditions[?(@.type=="Available")].status}') != "True" ]]; do
        echo "waiting for openldap to be ready"
        export openldapCaCert=$(kubectl get secret ldap -n openldap -o json | jq -r '.data."ca.crt"')
        sleep 10
    done
    sleep 30
    export openldapCaCert=$(kubectl get secret ldap -n openldap -o json | jq -r '.data."ca.crt"')
    ytt -f  templates/common/ldap-auth.yaml --data-value ldapCa=$openldapCaCert | kubectl apply -f -
    kubectl annotate packageinstalls tanzu-mission-control -n tmc-local ext.packaging.carvel.dev/ytt-paths-from-secret-name.0=tmc-overlay-override
    kubectl patch -n tmc-local --type merge pkgi tanzu-mission-control --patch '{"spec": {"paused": true}}'
    kubectl patch -n tmc-local --type merge pkgi tanzu-mission-control --patch '{"spec": {"paused": false}}'
fi


kubectx $wcp_ip
export caCert=$(yq eval '.trustedCAs."custom-ca.pem"' ./values.yaml)
export tmcURL=$(yq eval '.dnsZone' ./values.yaml)
export tmcNS=$(kubectl get ns|grep svc-tmc|awk '{ print $1 }')
yq e -i ".spec.caCerts = strenv(caCert)" ./templates/common/agentconfig.yaml
yq e -i ".spec.allowedHostNames = [env(tmcURL)]" ./templates/common/agentconfig.yaml
yq e -i ".metadata.namespace = strenv(tmcNS)" ./templates/common/agentconfig.yaml
yq e -i ".metadata.namespace = strenv(tmcNS)" ./templates/common/agentinstall.yaml

kubectl apply -f ./templates/common/agentconfig.yaml

kubectx $tmc_cluster
echo "-------------------"
echo Open TMC-SM via this URL: https://$tmc_dns
echo "-------------------"
echo "if on vSphere 8, run below command on supervisor level before creating each new workload cluster "
echo " "
echo "ytt -f templates/values-template.yaml -f templates/vsphere-8/cluster-config.yaml | kubectl apply -f -"
echo " "
