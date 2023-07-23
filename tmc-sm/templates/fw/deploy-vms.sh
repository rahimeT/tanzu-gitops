#!/bin/bash


export vcenterSsoUser=$(yq eval '.vcenter.user' ./templates/fw/values-test-network.yaml)
export vCenterAddress=$(yq eval '.vcenter.fqdn' ./templates/fw/values-test-network.yaml)
export vcenterSsoPassword=$(yq eval '.vcenter.password' ./templates/fw/values-test-network.yaml)
export GOVC_URL=$(echo ${vcenterSsoUser}:${vcenterSsoPassword}@${vCenterAddress})
export GOVC_DATACENTER=$(yq eval '.test_vms.datacenter_name' ./templates/fw/values-test-network.yaml)
export ESXis=$(yq eval '.ESXis' ./templates/fw/values-test-network.yaml)
#export GOVC_RESOURCE_POOL=''
#export GOVC_RESOURCE_POOL='/vmw-dc/host/vmw-vsan/Resources/gorkem'

export GOVC_INSECURE=1

export DATASTORE=$(yq eval '.test_vms.datastore_name' ./templates/fw/values-test-network.yaml)
export NTP_IP=$(yq eval '.test_vms.ntp' ./templates/fw/values-test-network.yaml)
export DNS_IP=$(yq eval '.test_vms.dns' ./templates/fw/values-test-network.yaml)
export DNS_DOMAIN=$(yq eval '.test_vms.dns_domain' ./templates/fw/values-test-network.yaml)

export MGT_IP=$(yq eval '.test_vms.vm_1.ip' ./templates/fw/values-test-network.yaml)
export MGT_GW=$(yq eval '.test_vms.vm_1.gateway' ./templates/fw/values-test-network.yaml)
export MGT_NETMASK=$(yq eval '.test_vms.vm_1.netmask' ./templates/fw/values-test-network.yaml)
export MGT_PG=$(yq eval '.test_vms.vm_1.port_group_name' ./templates/fw/values-test-network.yaml)

export W0_IP=$(yq eval '.test_vms.vm_2.ip' ./templates/fw/values-test-network.yaml)
export W0_GW=$(yq eval '.test_vms.vm_2.gateway' ./templates/fw/values-test-network.yaml)
export W0_NETMASK=$(yq eval '.test_vms.vm_2.netmask' ./templates/fw/values-test-network.yaml)
export W0_PG=$(yq eval '.test_vms.vm_2.port_group_name' ./templates/fw/values-test-network.yaml)

export W1_IP=$(yq eval '.test_vms.vm_3.ip' ./templates/fw/values-test-network.yaml)
export W1_GW=$(yq eval '.test_vms.vm_3.gateway' ./templates/fw/values-test-network.yaml)
export W1_NETMASK=$(yq eval '.test_vms.vm_3.netmask' ./templates/fw/values-test-network.yaml)
export W1_PG=$(yq eval '.test_vms.vm_3.port_group_name' ./templates/fw/values-test-network.yaml)

govc library.create -ds=$DATASTORE local-sivt
govc library.import -k=true -m=true -n service-installer-for-vmware-tanzu-2.2.0.18-21851770.ova local-sivt airgapped-files/ova/service-installer-for-vmware-tanzu-2.2.0.18-21851770.ova

mkdir -p templates/fw
cat > ./templates/fw/mgt.json <<-EOF
{
    "DiskProvisioning": "thin",
    "IPAllocationPolicy": "dhcpPolicy",
    "IPProtocol": "IPv4",
    "PropertyMapping": [
        {
            "Key": "sivt.password",
            "Value": "VMware1!"
        },
        {
            "Key": "appliance.ntp",
            "Value": "${NTP_IP}"
        },
        {
            "Key": "vami.gateway.Service_Installer_for_VMware_Tanzu",
            "Value": "${MGT_GW}"
        },
        {
            "Key": "vami.domain.Service_Installer_for_VMware_Tanzu",
            "Value": "arcas-mgt"
        },
        {
            "Key": "vami.searchpath.Service_Installer_for_VMware_Tanzu",
            "Value": "${DNS_DOMAIN}"
        },
        {
            "Key": "vami.DNS.Service_Installer_for_VMware_Tanzu",
            "Value": "${DNS_IP}"
        },
        {
            "Key": "vami.ip0.Service_Installer_for_VMware_Tanzu",
            "Value": "${MGT_IP}"
        },
        {
            "Key": "vami.netmask0.Service_Installer_for_VMware_Tanzu",
            "Value": "${MGT_NETMASK}"
        }
    ],
    "NetworkMapping": [
        {
            "Name": "Appliance Network",
            "Network": "${MGT_PG}"
        }
    ],
    "MarkAsTemplate": false,
    "PowerOn": false,
    "InjectOvfEnv": false,
    "WaitForIP": false,
    "Name": null
}
EOF

cat > ./templates/fw/w0.json <<-EOF
{
    "DiskProvisioning": "thin",
    "IPAllocationPolicy": "dhcpPolicy",
    "IPProtocol": "IPv4",
    "PropertyMapping": [
        {
            "Key": "sivt.password",
            "Value": "VMware1!"
        },
        {
            "Key": "appliance.ntp",
            "Value": "${NTP_IP}"
        },
        {
            "Key": "vami.gateway.Service_Installer_for_VMware_Tanzu",
            "Value": "${W0_GW}"
        },
        {
            "Key": "vami.domain.Service_Installer_for_VMware_Tanzu",
            "Value": "arcas-w0"
        },
        {
            "Key": "vami.searchpath.Service_Installer_for_VMware_Tanzu",
            "Value": "${DNS_DOMAIN}"
        },
        {
            "Key": "vami.DNS.Service_Installer_for_VMware_Tanzu",
            "Value": "${DNS_IP}"
        },
        {
            "Key": "vami.ip0.Service_Installer_for_VMware_Tanzu",
            "Value": "${W0_IP}"
        },
        {
            "Key": "vami.netmask0.Service_Installer_for_VMware_Tanzu",
            "Value": "${W0_NETMASK}"
        }
    ],
    "NetworkMapping": [
        {
            "Name": "Appliance Network",
            "Network": "${W0_PG}"
        }
    ],
    "MarkAsTemplate": false,
    "PowerOn": false,
    "InjectOvfEnv": false,
    "WaitForIP": false,
    "Name": null
}
EOF

cat > ./templates/fw/w1.json <<-EOF
{
    "DiskProvisioning": "thin",
    "IPAllocationPolicy": "dhcpPolicy",
    "IPProtocol": "IPv4",
    "PropertyMapping": [
        {
            "Key": "sivt.password",
            "Value": "VMware1!"
        },
        {
            "Key": "appliance.ntp",
            "Value": "${NTP_IP}"
        },
        {
            "Key": "vami.gateway.Service_Installer_for_VMware_Tanzu",
            "Value": "${W1_GW}"
        },
        {
            "Key": "vami.domain.Service_Installer_for_VMware_Tanzu",
            "Value": "arcas-w1"
        },
        {
            "Key": "vami.searchpath.Service_Installer_for_VMware_Tanzu",
            "Value": "${DNS_DOMAIN}"
        },
        {
            "Key": "vami.DNS.Service_Installer_for_VMware_Tanzu",
            "Value": "${DNS_IP}"
        },
        {
            "Key": "vami.ip0.Service_Installer_for_VMware_Tanzu",
            "Value": "${W1_IP}"
        },
        {
            "Key": "vami.netmask0.Service_Installer_for_VMware_Tanzu",
            "Value": "${W1_NETMASK}"
        }
    ],
    "NetworkMapping": [
        {
            "Name": "Appliance Network",
            "Network": "${W1_PG}"
        }
    ],
    "MarkAsTemplate": false,
    "PowerOn": false,
    "InjectOvfEnv": false,
    "WaitForIP": false,
    "Name": null
}
EOF



govc library.deploy -options ./templates/fw/mgt.json local-sivt/service-installer-for-vmware-tanzu-2.2.0.18-21851770.ova tanzu-fw-control-mgt
govc vm.power -on tanzu-fw-control-mgt
govc library.deploy -options ./templates/fw/w0.json local-sivt/service-installer-for-vmware-tanzu-2.2.0.18-21851770.ova tanzu-fw-control-w0
govc vm.power -on tanzu-fw-control-w0
govc library.deploy -options ./templates/fw/w1.json local-sivt/service-installer-for-vmware-tanzu-2.2.0.18-21851770.ova tanzu-fw-control-w1
govc vm.power -on tanzu-fw-control-w1

#########################################################################################################MGT
cat > ./templates/fw/run-network-test-mgt.sh <<-'EOF'
#!/bin/bash
export ports_to_serve_mgt='80, 443, 22, 5000, 6443, 8443, 8888, 9000, 9001, 9443'
export ports_mgt_to_w0='443, 22, 6443, 9443'
export ports_mgt_to_w1='443, 22, 6443'
EOF
cat >> ./templates/fw/run-network-test-mgt.sh <<-EOF
export MGT_GW=$(yq eval '.test_vms.vm_1.gateway' ./templates/fw/values-test-network.yaml)
export NTP_IP=$(yq eval '.test_vms.ntp' ./templates/fw/values-test-network.yaml)
export vCenterAddress=$(yq eval '.vcenter.fqdn' ./templates/fw/values-test-network.yaml)
export DNS_IP=$(yq eval '.test_vms.dns' ./templates/fw/values-test-network.yaml)
export W0_IP=$(yq eval '.test_vms.vm_2.ip' ./templates/fw/values-test-network.yaml)
export W1_IP=$(yq eval '.test_vms.vm_3.ip' ./templates/fw/values-test-network.yaml)
EOF
cat >> ./templates/fw/run-network-test-mgt.sh <<-'EOF'
systemctl stop iptables && systemctl stop arcas && systemctl stop nginx
python ports.py -listener_ports $ports_to_serve_mgt -log_path '/tmp/logfile.log' &
python ports.py -log_path '/tmp/logfile.log' -gateway $MGT_GW -ntp_server $NTP_IP -vcenter_fqdn $vCenterAddress -dns_server $DNS_IP
python ports.py -remote_ip $W0_IP -remote_ports $ports_mgt_to_w0 -log_path '/tmp/logfile.log'
python ports.py -remote_ip $W1_IP -remote_ports $ports_mgt_to_w1 -log_path '/tmp/logfile.log'
EOF
#########################################################################################################MGT

#########################################################################################################W0
cat > ./templates/fw/run-network-test-w0.sh <<-'EOF'
#!/bin/bash
export ports_to_serve_w0='80, 443, 22, 6443, 9443, 30001, 31010, 61001, 61010'
export ports_w0_to_mgt='443, 22, 6443, 9443, 9000, 9001, 8443'
export ports_w0_to_w1='443, 6443, 2112, 2113'
EOF
cat >> ./templates/fw/run-network-test-w0.sh <<-EOF
export W0_GW=$(yq eval '.test_vms.vm_2.gateway' ./templates/fw/values-test-network.yaml)
export NTP_IP=$(yq eval '.test_vms.ntp' ./templates/fw/values-test-network.yaml)
export vCenterAddress=$(yq eval '.vcenter.fqdn' ./templates/fw/values-test-network.yaml)
export DNS_IP=$(yq eval '.test_vms.dns' ./templates/fw/values-test-network.yaml)
export MGT_IP=$(yq eval '.test_vms.vm_1.ip' ./templates/fw/values-test-network.yaml)
export W1_IP=$(yq eval '.test_vms.vm_3.ip' ./templates/fw/values-test-network.yaml)
EOF
cat >> ./templates/fw/run-network-test-w0.sh <<-'EOF'
systemctl stop iptables && systemctl stop arcas && systemctl stop nginx
python ports.py -listener_ports $ports_to_serve_w0 -log_path '/tmp/logfile.log' &
python ports.py -log_path '/tmp/logfile.log' -gateway $W0_GW -ntp_server $NTP_IP -vcenter_fqdn $vCenterAddress -dns_server $DNS_IP
python ports.py -remote_ip $MGT_IP -remote_ports $ports_w0_to_mgt -log_path '/tmp/logfile.log'
python ports.py -remote_ip $W1_IP -remote_ports $ports_w0_to_w1 -log_path '/tmp/logfile.log'
EOF
#########################################################################################################W0
#########################################################################################################W1
cat > ./templates/fw/run-network-test-w1.sh <<-'EOF'
#!/bin/bash
export ports_to_serve_w1='80, 443, 22, 6443, 2112, 2113, 8443, 8080'
export ports_w1_to_mgt='6443, 8443'
export ports_w1_to_w0='80, 443, 6443, 30001, 31010, 61001, 61010'
EOF
cat >> ./templates/fw/run-network-test-w1.sh <<-EOF
export W1_GW=$(yq eval '.test_vms.vm_3.gateway' ./templates/fw/values-test-network.yaml)
export NTP_IP=$(yq eval '.test_vms.ntp' ./templates/fw/values-test-network.yaml)
export vCenterAddress=$(yq eval '.vcenter.fqdn' ./templates/fw/values-test-network.yaml)
export DNS_IP=$(yq eval '.test_vms.dns' ./templates/fw/values-test-network.yaml)
export MGT_IP=$(yq eval '.test_vms.vm_1.ip' ./templates/fw/values-test-network.yaml)
export W0_IP=$(yq eval '.test_vms.vm_2.ip' ./templates/fw/values-test-network.yaml)
EOF
cat >> ./templates/fw/run-network-test-w1.sh <<-'EOF'
systemctl stop iptables && systemctl stop arcas && systemctl stop nginx
python ports.py -listener_ports $ports_to_serve_w1 -log_path '/tmp/logfile.log' &
python ports.py -log_path '/tmp/logfile.log' -gateway $W1_GW -ntp_server $NTP_IP -vcenter_fqdn $vCenterAddress -dns_server $DNS_IP
python ports.py -remote_ip $MGT_IP -remote_ports $ports_w1_to_mgt -log_path '/tmp/logfile.log'
python ports.py -remote_ip $W0_IP -remote_ports $ports_w1_to_w0 -log_path '/tmp/logfile.log'
EOF
#########################################################################################################W1
until sshpass -p 'VMware1!' scp -oStrictHostKeyChecking=no ./templates/fw/run-network-test-mgt.sh root@$MGT_IP:/tmp/run-network-test-mgt.sh; do sleep 1; done
until sshpass -p 'VMware1!' scp -oStrictHostKeyChecking=no ./templates/fw/run-network-test-w0.sh root@$W0_IP:/tmp/run-network-test-w0.sh; do sleep 1; done
until sshpass -p 'VMware1!' scp -oStrictHostKeyChecking=no ./templates/fw/run-network-test-w1.sh root@$W1_IP:/tmp/run-network-test-w1.sh; do sleep 1; done

until sshpass -p 'VMware1!' scp -oStrictHostKeyChecking=no ./templates/fw/ports.py root@$MGT_IP:/tmp/ports.py; do sleep 1; done
until sshpass -p 'VMware1!' scp -oStrictHostKeyChecking=no ./templates/fw/ports.py root@$W0_IP:/tmp/ports.py; do sleep 1; done
until sshpass -p 'VMware1!' scp -oStrictHostKeyChecking=no ./templates/fw/ports.py root@$W1_IP:/tmp/ports.py; do sleep 1; done

until sshpass -p 'VMware1!' ssh -oStrictHostKeyChecking=no root@$MGT_IP "chmod +x /tmp/run-network-test-mgt.sh && /tmp/run-network-test-mgt.sh"; do sleep 1; done
until sshpass -p 'VMware1!' ssh -oStrictHostKeyChecking=no root@$W0_IP "chmod +x /tmp/run-network-test-w0.sh && /tmp/run-network-test-w0.sh"; do sleep 1; done
until sshpass -p 'VMware1!' ssh -oStrictHostKeyChecking=no root@$W1_IP "chmod +x /tmp/run-network-test-w1.sh && /tmp/run-network-test-w1.sh"; do sleep 1; done

sleep 60

until sshpass -p 'VMware1!' ssh -oStrictHostKeyChecking=no root@$MGT_IP "hostname && cat /tmp/logfile.log"; do sleep 1; done
until sshpass -p 'VMware1!' ssh -oStrictHostKeyChecking=no root@$W0_IP "hostname && cat /tmp/logfile.log"; do sleep 1; done
until sshpass -p 'VMware1!' ssh -oStrictHostKeyChecking=no root@$W1_IP "hostname && cat /tmp/logfile.log"; do sleep 1; done