#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 gen-cert|prep|import-cli|import-packages|post-install"
    exit 1
fi

yq eval '.' ./templates/values-template.yaml
export yaml_check=$?

if [ $yaml_check -eq 0 ]; then
    echo "Valid yaml structure for: values-template.yaml . Continuing."
else
    echo ""
    echo "Invalid yaml structure for: values-template.yaml . Check values-template.yaml"
    exit 1
fi

export TLD_DOMAIN=$(yq eval '.tld_domain' ./templates/values-template.yaml)
export DOMAIN=*.$TLD_DOMAIN
export std_repo=$(yq eval '.std_repo' ./templates/values-template.yaml)
export tmc_repo=$(yq eval '.tmc_repo' ./templates/values-template.yaml)
export TMC_SM_DL_URL="https://artifactory.eng.vmware.com/artifactory/tmc-generic-local/bundle-$tmc_repo.tar"

if [ "$1" = "prep" ]; then
    echo prep
    mkdir -p airgapped-files/images
    wget -P airgapped-files/ "$TMC_SM_DL_URL"
    templates/carvel.sh download
    imgpkg copy -b projects.registry.vmware.com/tkg/packages/standard/repo:$std_repo --to-tar airgapped-files/$std_repo.tar --include-non-distributable-layers --concurrency 30
    imgpkg copy -i ghcr.io/carvel-dev/kapp-controller@sha256:8011233b43a560ed74466cee4f66246046f81366b7695979b51e7b755ca32212 --to-tar=airgapped-files/images/kapp-controller.tar --concurrency 30
    imgpkg copy -i projects.registry.vmware.com/tanzu_meta_pocs/tools/busybox:latest --to-tar=airgapped-files/images/busybox.tar --concurrency 30
    imgpkg copy -i projects.registry.vmware.com/tanzu_meta_pocs/tools/openldap:1.2.4 --to-tar=airgapped-files/images/openldap.tar --concurrency 30
elif [ "$1" = "import-cli" ]; then
    echo import-cli
    templates/carvel.sh install
elif [ "$1" = "import-packages" ]; then
    echo import-packages
    if [ -f ca.crt ] ; then
        export CA_CERT=$(cat ./ca.crt)
        cp ca.crt /etc/ssl/certs/
        echo "required files exist, continuing."
    else
        echo "no ca.crt fall back to values-template.yaml"
        export CA_CERT=$(yq eval '.trustedCAs.ca' ./templates/values-template.yaml)
        echo "$CA_CERT" > ./ca.crt
        echo "$CA_CERT" > /etc/ssl/certs/ca.crt
    fi
    export HARBOR_URL=$(yq eval '.harbor.fqdn' ./templates/values-template.yaml)
    export HARBOR_USER=$(yq eval '.harbor.user' ./templates/values-template.yaml)
    export HARBOR_PASS=$(yq eval '.harbor.pass' ./templates/values-template.yaml)
    export HARBOR_CERT=$(echo | openssl s_client -connect $HARBOR_URL:443 2>&1 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p')
    openssl verify -CAfile <(echo "$CA_CERT") <(echo "$HARBOR_CERT")
    export harbor_cert_check=$?
    if [ $harbor_cert_check -eq 0 ]; then
        echo "Valid Harbor Cert , Continuing."
    else
        echo ""
        echo "INVALID Harbor Cert , Check Harbor Cert and CA Cert."
        exit 1
    fi
    tar -xvf airgapped-files/bundle*.tar
    export IMGPKG_REGISTRY_USERNAME=$HARBOR_USER && export IMGPKG_REGISTRY_PASSWORD=$HARBOR_PASS &&  export IMGPKG_REGISTRY_HOSTNAME=$HARBOR_URL
    curl -u "${IMGPKG_REGISTRY_USERNAME}:${IMGPKG_REGISTRY_PASSWORD}" -X POST -H "content-type: application/json" "https://$HARBOR_URL/api/v2.0/projects" -d "{\"project_name\": \"tmc\", \"public\": true, \"storage_limit\": -1 }" -k
    ./tmc-sm push-images harbor --project $HARBOR_URL/tmc --username $HARBOR_USER --password $HARBOR_PASS --concurrency 10
    imgpkg copy --tar airgapped-files/$std_repo.tar --to-repo $HARBOR_URL/tmc/498533941640.dkr.ecr.us-west-2.amazonaws.com/packages/standard/repo --include-non-distributable-layers
    imgpkg copy --tar airgapped-files/images/kapp-controller.tar --to-repo $HARBOR_URL/tmc/kapp-controller --include-non-distributable-layers
    imgpkg copy --tar airgapped-files/images/busybox.tar --to-repo $HARBOR_URL/tmc/busybox --include-non-distributable-layers
    imgpkg copy --tar airgapped-files/images/openldap.tar --to-repo $HARBOR_URL/tmc/openldap --include-non-distributable-layers
elif [ "$1" = "gen-cert" ]; then
    templates/gen-cert.sh
elif [ "$1" = "post-install" ]; then
    kubectl get httpproxy -A
    echo "-------------------"
    kubectl get svc -A|grep LoadBalancer
    echo "-------------------"
    echo "on vSphere 8, run below command on supervisor level before creating workload cluster "
    echo " "
    echo "ytt -f templates/values-template.yaml -f templates/vsphere-8/cluster-config.yaml | kubectl apply -f -"
fi