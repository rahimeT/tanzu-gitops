# TMC Self-Managed Opinionated Install Guide (WIP)

Pre requirement before start: 
 - Harbor with proper CA Cert chain.
    - ```00-prep.sh``` script will validate the Harbor's Certificates.
    - If Certs cannot be trusted in chain, it will intentionally throw error and stop.
 - If you're using your own certificates, 
    - make sure that creating following files into ```tmc-sm``` folder
        - ```ca.crt``` for Root CA Cert and if present Intermediate Cert
        - ```ca-no-pass.key``` for un-encrypted Root CA Cert Key for wildcard certs
 - Have DNS A records to be added for *.tmc.corp.com and tmc.corp.com with pre-selected LB IP address.

![Alt text](image.png)

## Getting Started Quick

git clone the repo and update the `templates/values-template.yaml` file.

```bash
git clone https://github.com/gorkemozlu/tanzu-gitops
cd tmc-sm/
vi templates/values-template.yaml
```

If you need to create required certificates: (You can use these certs for Harbor as well)
```
$ ./00-prep.sh gen-cert
```

You can easily update the `templates/values-template.yaml` file with CA Certs/Keys with below commands.
```
export CA_CERT=$(cat ./ca.crt)
yq e -i ".trustedCAs.ca = strenv(CA_CERT)" ./templates/values-template.yaml
export CA_KEY=$(cat ./ca-no-pass.key)
yq e -i ".trustedCAs.key = strenv(CA_KEY)" ./templates/values-template.yaml
```

For airgapped environments, run the ```00-prep.sh``` script.

Downloading required all packages.
```
$ ./00-prep.sh prep
```

If your jumpbox does not have internet connection, you need to manually transfer downloaded files (TMC-SM files, images etc.) into ```airgapped-files/``` folder.

Importing required all CLIs
```
$ ./00-prep.sh import-cli
```

Importing required all packages.
```
$ ./00-prep.sh import-packages
```

Then run the ```01-setup.sh``` for installation.

If you have TKGs on vSphere 7:
```
$ ./01-setup.sh vsphere-7
```

If you have TKGs on vSphere 8:
```
$ ./01-setup.sh vsphere-8
```


## For troubleshooting:

export all TMC-SM pod logs into log files.
```
export ns=tmc-local && kubectl get pods -n $ns --no-headers=true -o custom-columns=:metadata.name | xargs -I {} sh -c 'kubectl get pods -n $ns {} -o jsonpath="{.spec.containers[*].name}" | tr " " "\n" | xargs -I {container} sh -c "kubectl logs -n $ns {} {container} > {}-{container}.log"'
```

export all TMC-SM CrashLoopBackOff pod logs into log files.
```
export ns=tmc-local && kubectl get pods -n $ns --no-headers=true -o custom-columns=:metadata.name | xargs -I {} sh -c 'status=$(kubectl get pod -n $ns {} -o jsonpath="{.status.containerStatuses[*].state.waiting.reason}") && [ "$status" = "CrashLoopBackOff" ] && kubectl get pods -n $ns {} -o jsonpath="{.spec.containers[*].name}" | tr " " "\n" | xargs -I {container} sh -c "kubectl logs -n $ns {} {container} > {}-{container}.log"'
```

extract/read error logs from each log file.
```
for file in *.log; do grep -q "error" "$file" && (echo "=== $file ==="; grep "error" "$file"; echo); done
```