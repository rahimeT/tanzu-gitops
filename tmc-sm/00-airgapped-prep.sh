#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 gen-cert|prep|import-cli|import-packages|post-install"
    exit 1
fi

export TLD_DOMAIN=$(yq eval '.tld_domain' ./templates/values-template.yaml)
export DOMAIN=*.$TLD_DOMAIN
export REGISTRY_CA_PATH="$(pwd)/ca.crt"
export std_repo=$(yq eval '.std_repo' ./templates/values-template.yaml)

if [ "$1" = "prep" ]; then
    echo prep
    mkdir -p airgapped-files/images
    wget "$TMC_SM_DL_URL"
    templates/carvel.sh download
    imgpkg copy -b projects.registry.vmware.com/tkg/packages/standard/repo:$std_repo --to-tar airgapped-files/$std_repo.tar --include-non-distributable-layers --concurrency 30
    imgpkg copy -i projects.registry.vmware.com/tkg/kapp-controller:v0.30.0_vmware.1 --to-tar=airgapped-files/images/kapp-controller-v030.tar --concurrency 30
    imgpkg copy -i projects.registry.vmware.com/tanzu_meta_pocs/tools/busybox:latest --to-tar=airgapped-files/images/busybox.tar --concurrency 30
    imgpkg copy -i projects.registry.vmware.com/tanzu_meta_pocs/tools/openldap:1.2.4 --to-tar=airgapped-files/images/openldap.tar --concurrency 30
elif [ "$1" = "import-cli" ]; then
    echo import-cli
    templates/carvel.sh install
elif [ "$1" = "import-packages" ]; then
    echo import-packages
    cp ca.crt /etc/ssl/certs/
    tar -xvf airgapped-files/bundle*.tar
    export IMGPKG_REGISTRY_USERNAME=admin && export IMGPKG_REGISTRY_PASSWORD='VMware1!' &&  export IMGPKG_REGISTRY_HOSTNAME=harbor.$TLD_DOMAIN
    curl -u "${IMGPKG_REGISTRY_USERNAME}:${IMGPKG_REGISTRY_PASSWORD}" -X POST -H "content-type: application/json" "https://harbor.$TLD_DOMAIN/api/v2.0/projects" -d "{\"project_name\": \"tmc\", \"public\": true, \"storage_limit\": -1 }" -k
    ./tmc-local push-images harbor --project harbor.$TLD_DOMAIN/tmc --username admin --password VMware1! --concurrency 10
    imgpkg copy --tar airgapped-files/$std_repo.tar --to-repo harbor.$TLD_DOMAIN/tmc/498533941640.dkr.ecr.us-west-2.amazonaws.com/packages/standard/repo --include-non-distributable-layers --registry-ca-cert-path $REGISTRY_CA_PATH
    imgpkg copy --tar airgapped-files/images/kapp-controller-v030.tar --to-repo harbor.$TLD_DOMAIN/tmc/kapp-controller --include-non-distributable-layers --registry-ca-cert-path $REGISTRY_CA_PATH
    imgpkg copy --tar airgapped-files/images/busybox.tar --to-repo harbor.$TLD_DOMAIN/tmc/busybox --include-non-distributable-layers --registry-ca-cert-path $REGISTRY_CA_PATH
    imgpkg copy --tar airgapped-files/images/openldap.tar --to-repo harbor.$TLD_DOMAIN/tmc/openldap --include-non-distributable-layers --registry-ca-cert-path $REGISTRY_CA_PATH
elif [ "$1" = "gen-cert" ]; then
    templates/gen-cert.sh
elif [ "$1" = "post-install" ]; then
    kubectl get httpproxy -A
    kubectl get svc -A|grep LoadBalancer
fi