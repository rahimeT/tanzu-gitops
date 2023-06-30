#!/bin/bash

export TLD_DOMAIN=$(yq eval '.tld_domain' ./templates/values-template.yaml)

# Check if the variable contains ".local" string
if [[ "$TLD_DOMAIN" != *".local"* ]]; then
    echo "Top Level Domain does not have '.local', continue."
    exit 0
fi

echo "Top Level Domain has '.local', this is not recommended, applying fix on Supervisor."
export TLD_LOCAL=$(echo "$TLD_DOMAIN" |grep -oE '[^.]+\.local')
export vcenter_fqdn=$(yq eval '.vcenter.fqdn' ./templates/values-template.yaml)
export vcenter_pass=$(yq eval '.wcp.password' ./templates/values-template.yaml)
ytt -f templates/values-template.yaml -f templates/common/tld-local-fix.yaml --data-value tld_local_domain=$TLD_LOCAL > /tmp/tld-local-fix.yaml

export SV_PASS_=$(sshpass -p "${vcenter_pass}" ssh -t -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null  root@"${vcenter_fqdn}"  << EOF
/usr/lib/vmware-wcp/decryptK8Pwd.py|grep PWD
EOF
)
export SV_IP_=$(sshpass -p "${vcenter_pass}" ssh -t -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null  root@"${vcenter_fqdn}"  << EOF
/usr/lib/vmware-wcp/decryptK8Pwd.py|grep IP
EOF
)
export SV_PASS=$(echo $SV_PASS_|awk -F': ' '{print $2}')
export SV_IP=$(echo $SV_IP_|awk -F': ' '{print $2}')

sshpass -p "${SV_PASS}" scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /tmp/tld-local-fix.yaml root@"${SV_IP}":/tmp/tld-local-fix.yaml >> /dev/null
sshpass -p "${SV_PASS}" ssh -t -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null  root@"${SV_IP}"  << EOF
kubectl apply -f /tmp/tld-local-fix.yaml
EOF
