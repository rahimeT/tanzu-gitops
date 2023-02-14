#!/bin/bash

# requires ytt + yq + curl + kubectl
# no need to update bootstrap-config.yaml / interworking.yaml / values.yaml
# just change below variables

export clusterName=dev-cluster-04
export nsxtManager=nsxt01.h2o-4-6579.h2o.vmware.com
export nsxtPass=pass


mkdir cert
mkdir ${clusterName}
cd cert
if [[ ! -f private.key && ! -f cert.crt && ! -f csr.csr && ! -f .rnd ]] ; then
    echo "cert files does not exists."
    openssl genrsa -out private.key 2048
    openssl rand -writerand .rnd
    openssl req -new -key private.key -out csr.csr -subj "/C=US/ST=CA/L=Palo Alto/O=VMware/OU=Antrea Cluster/CN=*"
    openssl x509 -req -days 3650 -sha256 -in csr.csr -signkey private.key -out cert.crt
fi

export crt_one_line=$(cat cert.crt|awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' )
export crt=$(cat cert.crt|base64)
export key=$(cat private.key|base64)
cd ..
yq eval -i '.clusterName = "'"${clusterName}"'"' ./values.yaml
yq eval -i '.nsxtManager = "'"${nsxtManager}"'"' ./values.yaml

yq eval -i '.tls.crt = "'"${crt}"'"' ./values.yaml
yq eval -i '.tls.key = "'"${key}"'"' ./values.yaml

#curl https://$nsxtManager/api/v1/trust-management/principal-identities -k -u admin:$nsxtPass

curl -k -u admin:$nsxtPass -X POST https://$nsxtManager/api/v1/trust-management/principal-identities/with-certificate \
   -H "Content-Type: application/json" \
   -d "{
    \"name\": \"antrea-integration-user\",
    \"node_id\": \"test\",
    \"roles_for_paths\": [
        {
            \"path\": \"/\",
            \"roles\": [
                {
                    \"role\": \"enterprise_admin\"
                }
            ]
        }
    ],
    \"role\": \"enterprise_admin\",
    \"is_protected\": \"true\",
    \"certificate_pem\" : \"$crt_one_line\"
}"


ytt --ignore-unknown-comments -f values.yaml -f bootstrap-config.yaml -f interworking.yaml > ${clusterName}/${clusterName}.yaml
kubectl apply -f ${clusterName}/${clusterName}.yaml