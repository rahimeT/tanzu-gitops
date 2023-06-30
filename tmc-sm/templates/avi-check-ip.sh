#!/bin/bash
export AVI_USERNAME='admin'
export AVI_PASSWORD='VMware1!'
export AVI_HOSTNAME='avi01.h2o-4-12022.h2o.vmware.com'
curl -k -s -X POST "https://${AVI_USERNAME}:${AVI_PASSWORD}@${AVI_HOSTNAME}/api/vsvip" \
  -H "Content-Type: application/json" \
  -H "X-Avi-Version: 22.1.2" \
  -d "{\"name\": \"tmc-sm\", \"vip\": [{\"auto_allocate_floating_ip\": false, \"auto_allocate_ip\": true, \"auto_allocate_ip_type\": \"V4_ONLY\", \"avi_allocated_fip\": false, \"avi_allocated_vip\": false}]}" \
  -o vip.json
export VIP_UUID=$(yq eval '.uuid' vip.json -oyaml)
curl -k -s -X DELETE "https://${AVI_USERNAME}:${AVI_PASSWORD}@${AVI_HOSTNAME}/api/vsvip/${VIP_UUID}"
LB_IP=$(yq eval '.vip[].ip_address.addr' vip.json -oyaml)
echo "You can use below IP for TMC-SM LB IP"
echo $LB_IP