#!/bin/bash

yq eval '.' ./templates/values-template.yaml
export yaml_check=$?

if [ $yaml_check -eq 0 ]; then
    echo "Valid yaml structure for: values-template.yaml . Continuing."
else
    echo ""
    echo "Invalid yaml structure for: values-template.yaml . Check values-template.yaml"
    exit 1
fi

echo "###############################################################################Checking CLIs/Binaries files#"
binaries=("kubectl" "openssl" "jq" "yq" "govc" "dig" "kubectl-vsphere" "ytt" "curl" "git" "wget" "imgpkg")
missing_binaries=""
for binary in "${binaries[@]}"; do
    if ! command -v "$binary" >/dev/null 2>&1; then
        missing_binaries+="$binary "
    fi
done
if [ -n "$missing_binaries" ]; then
    echo "The following binaries are missing: $missing_binaries"
    exit 1
else
    echo "All CLIs are present."
fi

echo "##################################################################################Checking proxy on vCenter#"
export session_id=$(curl -s -k -X POST https://$GOVC_URL/rest/com/vmware/cis/session -u $GOVC_USERNAME:$GOVC_PASSWORD|jq '.value'| tr -d '"')
export httpproxystate=$(curl -s -k -X GET -H "vmware-api-session-id: ${session_id}" https://{$GOVC_URL}/api/appliance/networking/proxy|jq '.http.enabled')
export httpsproxystate=$(curl -s -k -X GET -H "vmware-api-session-id: ${session_id}" https://{$GOVC_URL}/api/appliance/networking/proxy|jq '.https.enabled')
if [ "$httpproxystate" = true ] || [ "$httpsproxystate" = true ]; then
    echo ""
    echo "Proxy is enabled on vCenter."
    echo "Please make sure that Proxy Server's IP:Port is reachable from Management and Workload Subnet."
    echo "Source: Management Subnet - Destination: Proxy IP - Port: Proxy Port"
    echo "Source: Workload Subnet - Destination: Proxy IP - Port: Proxy Port"
    echo ""
    echo "Or remove the proxy configuration from vCenter and retry again."
    exit 1
fi

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

echo "#######################################################################################Setting-up variables#"
export wcp_ip=$(yq eval '.wcp.ip' ./templates/values-template.yaml)
export wcp_user=$(yq eval '.wcp.user' ./templates/values-template.yaml)
export wcp_pass=$(yq eval '.wcp.password' ./templates/values-template.yaml)
export KUBECTL_VSPHERE_PASSWORD=$wcp_pass
export namespace=$(yq eval '.shared_cluster.namespace' ./templates/values-template.yaml)
export tmc_cluster='shared'
export tmc_dns=$(yq eval '.tld_domain' ./templates/values-template.yaml)
export tmc_repo=$(yq eval '.tmc_repo' ./templates/values-template.yaml)
export hostnames=($tmc_dns *.$tmc_dns)
export HARBOR_URL=$(yq eval '.harbor.fqdn' ./templates/values-template.yaml)
export HARBOR_USER=$(yq eval '.harbor.user' ./templates/values-template.yaml)
export HARBOR_PASS=$(yq eval '.harbor.pass' ./templates/values-template.yaml)
export IMGPKG_REGISTRY_USERNAME=$HARBOR_USER && export IMGPKG_REGISTRY_PASSWORD=$HARBOR_PASS &&  export IMGPKG_REGISTRY_HOSTNAME=$HARBOR_URL

echo "#############################################################################################Pushing Images#"
mkdir -p old-tmc/
if [ ! -f airgapped-files/bundle-$tmc_repo.tar ] ; then
    echo "TMC-SM v$tmc_repo bundle file is not present. Please copy bundle-$tmc_repo.tar to airgapped-files/ folder. Exiting"
    exit 1
fi
mv agent-images/ old-tmc/ && mv dependencies/ old-tmc/
tar -xvf airgapped-files/bundle-$tmc_repo.tar
./tmc-sm push-images harbor --project $HARBOR_URL/tmc --username $HARBOR_USER --password $HARBOR_PASS --concurrency 10

echo "###########################################################################################Login to cluster#"
kubectl vsphere login --server=$wcp_ip --vsphere-username $wcp_user --insecure-skip-tls-verify
kubectl vsphere login --server=$wcp_ip --tanzu-kubernetes-cluster-name $tmc_cluster --tanzu-kubernetes-cluster-namespace $namespace --vsphere-username $wcp_user --insecure-skip-tls-verify

kubectx $tmc_cluster

echo "#######################################################################################Check TMC-SM Version#"
export tmc_repo=$(yq eval '.tmc_repo' ./templates/values-template.yaml)
export tmc_current_repo=$(kubectl --context=$tmc_cluster get pkgr tanzu-mission-control-packages -n tmc-local -o=jsonpath='{.spec.fetch.imgpkgBundle.image}'|awk -F':' '{print $2}')
export tmc_new_repo=$tmc_repo


if [[ $tmc_current_repo == $tmc_new_repo ]]; then
    echo "Versions are the same, will not upgrade! Please update your values-template.yaml. Exiting."
    exit 1
elif [[ $tmc_current_repo < $tmc_new_repo ]]; then
    echo "The new version is greater than currently deployed version. Continue."
else
    echo "The new version is lower than currently deployed version. Please update your values-template.yaml. Exiting."
    exit 1
fi

echo "########################################################################Checking TMC-SM Package Repo Status#"
if [[ $(kubectl --context=$tmc_cluster get pkgr tanzu-mission-control-packages -n tmc-local -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; then
    kubectl --context=$tmc_cluster get pkgr tanzu-mission-control-packages -n tmc-local
    echo " "
    echo "TMC-Repo is not ready, please check the problem." 
    exit 1
fi
echo "#############################################################################Checking TMC-SM Package Status#"
if [[ $(kubectl --context=$tmc_cluster get pkgi tanzu-mission-control -n tmc-local -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; then
    kubectl --context=$tmc_cluster get pkgi tanzu-mission-control -n tmc-local
    echo " "
    echo "TMC package is not ready, please check the problem." 
    exit 1
fi
echo "##############################################################################Upgrading TMC-SM Package Repo#"
ytt -f templates/values-template.yaml -f templates/common/tmc-repo.yaml | kubectl --context=$tmc_cluster apply -f -

while [[ "$(kubectl --context=$tmc_cluster get pkgr tanzu-mission-control-packages -n tmc-local -o=jsonpath='{.spec.fetch.imgpkgBundle.image}'|awk -F':' '{print $2}')" != "$tmc_new_repo" ]]; do
    echo "Waiting for tmc-repo to be updated: " $(kubectl --context=$tmc_cluster get pkgr tanzu-mission-control-packages -n tmc-local -o=jsonpath='{.spec.fetch.imgpkgBundle.image}'|awk -F':' '{print $2}')
    sleep 10
done
while [[ $(kubectl --context=$tmc_cluster get pkgr tanzu-mission-control-packages -n tmc-local -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; do
    echo "Waiting for tmc-repo to be ready: " $(kubectl --context=$tmc_cluster get pkgr tanzu-mission-control-packages -n tmc-local -o=jsonpath='{.status.conditions[0].type}')
    sleep 10
done


echo "###################################################################################Upgrading TMC-SM Package#"
ytt -f templates/values-template.yaml -f templates/common/tmc-values-template.yaml > values.yaml
export valuesContent=$(cat values.yaml)
ytt -f templates/values-template.yaml --data-value valuesContent="$valuesContent" -f templates/common/tmc-install.yaml | kubectl --context=$tmc_cluster apply -f -
while [[ $(kubectl --context=$tmc_cluster get pkgi tanzu-mission-control -n tmc-local -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; do
    echo "Waiting for tanzu-mission-control to be ready: " $(kubectl --context=$tmc_cluster get pkgi tanzu-mission-control -n tmc-local -o=jsonpath='{.status.conditions[0].type}')
    sleep 10
done

echo "##################################################################################Finished Deploying TMC-SM#"
echo "-------------------"
echo Open TMC-SM via this URL: https://$tmc_dns
echo "-------------------"