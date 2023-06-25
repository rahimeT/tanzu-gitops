#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 vsphere-7|vsphere-8"
    exit 1
fi
echo "#################################################################################Checking Certificate files#"
if [ -f tmc-ca.crt ] && [ -f tmc-ca-no-pass.key ]; then
    echo "required files exist, continuing."
else
    export TMC_CA_CERT=$(yq eval '.trustedCAs.tmc_ca' ./templates/values-template.yaml)
    export TMC_CA_KEY=$(yq eval '.trustedCAs.tmc_key' ./templates/values-template.yaml)
    export OTHER_CA_CERT=$(yq eval '.trustedCAs.other_ca' ./templates/values-template.yaml)
    export ALL_CA_CERT=$(echo -e "$TMC_CA_CERT""\n""$OTHER_CA_CERT")
    echo "$ALL_CA_CERT" > ./all-ca.crt
    echo "$TMC_CA_CERT" > ./tmc-ca.crt
    echo "$TMC_CA_KEY" > ./tmc-ca-no-pass.key
    if [ -s tmc-ca.crt ] && [ -s tmc-ca-no-pass.key ] && [ -s all-ca.crt ]; then
        echo "tmc-ca.crt, all-ca.crt and tmc-ca-no-pass.crt files created."
    else
        echo "The file is empty or does not exist."
        echo "check tmc-ca.crt and/or tmc-ca-no-pass.key and/or all-ca.crt"
        echo "check ./templates/values-template.yaml file for CA Certs and Key"
        exit 1
    fi
fi
echo "###################################################################################Checking vCenter version#"
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
echo "#######################################################################################Setting-up variables#"
export wcp_ip=$(yq eval '.wcp.ip' ./templates/values-template.yaml)
export wcp_user=$(yq eval '.wcp.user' ./templates/values-template.yaml)
export wcp_pass=$(yq eval '.wcp.password' ./templates/values-template.yaml)
export namespace=$(yq eval '.shared_cluster.namespace' ./templates/values-template.yaml)
export tmc_cluster='shared'
export ldap_auth=$(yq eval '.auth.ldap.enabled' ./templates/values-template.yaml)
export tmc_dns=$(yq eval '.tld_domain' ./templates/values-template.yaml)
export hostnames=($tmc_dns *.$tmc_dns)
echo "#####################################################################################Checking DNS A Records#"
for hostname in "${hostnames[@]}"; do
    output=$(dig +short "$hostname")
    if [[ -n "$output" ]]; then
        echo "DNS A record is resolvable for $hostname"
    else
        echo "DNS A record is not resolvable for $hostname"
        exit 1
    fi
done

cp all-ca.crt /etc/ssl/certs/

if [ "$1" = "vsphere-7" ]; then
    echo "####################################################################################Logging into Supervisor#"
    echo vsphere-7
    export KUBECTL_VSPHERE_PASSWORD=$wcp_pass
    kubectl vsphere login --server=$wcp_ip --vsphere-username $wcp_user --insecure-skip-tls-verify
    kubectx $wcp_ip
    echo "##############################################################Patching TkgServiceConfiguration with CA Cert#"
    export ALL_CA_CERT_B64=$(cat ./all-ca.crt|base64 -w0)
    kubectl patch TkgServiceConfiguration tkg-service-configuration --type merge -p '{"spec":{"trust":{"additionalTrustedCAs":[{"name":"root-ca-tmc","data":"'$(echo -n "$ALL_CA_CERT_B64")'"}]}}}'
    echo "####################################################################################Creating Shared Cluster#"
    ytt -f templates/values-template.yaml -f templates/vsphere-7/shared-cluster.yaml | kubectl apply -f -
    while [[ $(kubectl get tkc shared -o=jsonpath='{.status.conditions[?(@.type=="Ready")].status}' -n $namespace) != "True" ]]; do
        echo "Waiting for cluster to be ready"
        sleep 30
    done
    echo "################################################################################Logging into shared cluster#"
    kubectl vsphere login --server=$wcp_ip --tanzu-kubernetes-cluster-name shared --tanzu-kubernetes-cluster-namespace $namespace --vsphere-username $wcp_user --insecure-skip-tls-verify
    echo "#################################################################Changing kubectl context to shared cluster#"
    kubectx $tmc_cluster
    echo "###############################################################################################creating psp#"
    kubectl create clusterrolebinding default-tkg-admin-privileged-binding --clusterrole=psp:vmware-system-privileged --group=system:authenticated
    echo "##################################################################################Deploying kapp-controller#"
    ytt -f templates/common/kapp-controller.yaml -f templates/values-template.yaml | kubectl apply -f -
    while [[ $(kubectl get deployment kapp-controller -n kapp-controller -o=jsonpath='{.status.conditions[?(@.type=="Available")].status}') != "True" ]]; do
        echo "Waiting for kapp-controller to be ready"
        sleep 10
        kubectl get pods -n kapp-controller | grep -E 'ImagePullBackOff|ErrImagePull' | awk '{ print $1 }' | xargs kubectl delete pod -n kapp-controller
    done
elif [ "$1" = "vsphere-8" ]; then
    echo "####################################################################################Logging into Supervisor#"
    echo vsphere-8
    export KUBECTL_VSPHERE_PASSWORD=$wcp_pass
    kubectl vsphere login --server=$wcp_ip --vsphere-username $wcp_user --insecure-skip-tls-verify
    kubectx $wcp_ip
    echo "####################################################################################Creating Shared Cluster#"
    ytt -f templates/values-template.yaml -f templates/vsphere-8/shared-cluster.yaml | kubectl apply -f -
    while [[ $(kubectl get cluster shared -o=jsonpath='{.status.conditions[?(@.type=="Ready")].status}' -n $namespace) != "True" ]]; do
        echo "Waiting for cluster to be ready"
        sleep 30
    done
    echo "################################################################################Logging into shared cluster#"
    kubectl vsphere login --server=$wcp_ip --tanzu-kubernetes-cluster-name shared --tanzu-kubernetes-cluster-namespace $namespace --vsphere-username $wcp_user --insecure-skip-tls-verify
    kubectx $tmc_cluster
    export node_names=$(kubectl get nodes -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
    while [[ -z "$node_names" ]]; do
        node_names=$(kubectl get nodes -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
        if [[ -z "$node_names" ]]; then
            echo "Waiting for cluster to be ready"
            sleep 30
        fi
    done
    echo "###############################################################################################creating psp#"
    kubectl create clusterrolebinding default-tkg-admin-privileged-binding --clusterrole=psp:vmware-system-privileged --group=system:authenticated
fi

kubectx $tmc_cluster
echo "######################################################################Deploying Tanzu Standard Package Repo#"
ytt -f templates/common/std-repo.yaml -f templates/values-template.yaml | kubectl apply -f -
while [[ $(kubectl get pkgr tanzu-std-repo -n packages -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; do
    echo "Waiting for std-repo to be ready: " $(kubectl get pkgr tanzu-std-repo -n packages -o=jsonpath='{.status.conditions[0].type}')
    sleep 10
    if [[ $(kubectl get pkgr tanzu-std-repo -n packages -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') == "ReconcileFailed" ]]; then
        kubectl get pkgr tanzu-std-repo -n packages -o=jsonpath='{.status.usefulErrorMessage}'
        ytt -f templates/common/std-repo.yaml -f templates/values-template.yaml | kubectl delete -f -
        sleep 5
        ytt -f templates/common/std-repo.yaml -f templates/values-template.yaml | kubectl apply -f -
    fi
done
echo "#############################################################################Deploying Cert-Manager Package#"
ytt -f templates/common/cert-manager.yaml -f templates/values-template.yaml | kubectl apply -f -
while [[ $(kubectl get pkgi cert-manager -n packages -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; do
    echo "Waiting for cert-manager to be ready: " $(kubectl get pkgi cert-manager -n packages -o=jsonpath='{.status.conditions[0].type}')
    sleep 10
    kubectl get pods -n cert-manager | grep -E 'ImagePullBackOff|ErrImagePull' | awk '{ print $1 }' | xargs kubectl delete pod -n cert-manager
done
echo "#####################################################################Creating ClusterIssuer on Cert-Manager#"
kubectl create secret tls local-ca --key tmc-ca-no-pass.key --cert tmc-ca.crt -n cert-manager
kubectl apply -f templates/common/local-issuer.yaml
ytt -f templates/values-template.yaml -f templates/common/tmc-values-template.yaml > values.yaml
echo "##############################################################################Deploying TMC-SM Package Repo#"
ytt -f templates/values-template.yaml -f templates/common/tmc-repo.yaml | kubectl apply -f -
while [[ $(kubectl get pkgr tanzu-mission-control-packages -n tmc-local -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; do
    echo "Waiting for tmc-repo to be ready: " $(kubectl get pkgr tanzu-mission-control-packages -n tmc-local -o=jsonpath='{.status.conditions[0].type}')
    sleep 10
done

export valuesContent=$(cat values.yaml)
echo "###################################################################################Deploying TMC-SM Package#"
ytt -f templates/values-template.yaml --data-value valuesContent="$valuesContent" -f templates/common/tmc-install.yaml | kubectl apply -f -
while [[ $(kubectl get pkgi tanzu-mission-control -n tmc-local -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; do
    echo "Waiting for tanzu-mission-control to be ready: " $(kubectl get pkgi tanzu-mission-control -n tmc-local -o=jsonpath='{.status.conditions[0].type}')
    sleep 10
done
if [ "$ldap_auth" = "true" ]; then
    echo "#########################################################################################Deploying OpenLDAP#"
    ytt -f templates/values-template.yaml -f templates/common/openldap.yaml | kubectl apply -f -
    kubectl apply -f templates/common/ldap-overlay.yaml
    while [[ $(kubectl get deployment openldap -n openldap -o=jsonpath='{.status.conditions[?(@.type=="Available")].status}') != "True" ]]; do
        echo "Waiting for openldap to be ready"
        export openldapCaCert=$(kubectl get secret ldap -n openldap -o json | jq -r '.data."ca.crt"')
        sleep 10
    done
    sleep 30
    export openldapCaCert=$(kubectl get secret ldap -n openldap -o json | jq -r '.data."ca.crt"')
    echo "######################################################################################Applying LDAP Overlay#"
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
echo "#######################################################################################Applying AgentConfig#"
kubectl apply -f ./templates/common/agentconfig.yaml

kubectx $tmc_cluster
echo "##################################################################################Finished Deploying TMC-SM#"
echo "-------------------"
echo Open TMC-SM via this URL: https://$tmc_dns
echo "-------------------"

if [[ "$vCenter_version" == "8.0.1" ]]; then
    echo "Run below command on supervisor level before creating each new workload cluster "
    echo " "
    echo "ytt -f templates/values-template.yaml -f templates/vsphere-8/cluster-config.yaml | kubectl apply -f -"
    echo " "
fi