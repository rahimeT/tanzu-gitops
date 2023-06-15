# TMC Self-Managed Opinionated Install Guide (WIP)

Pre requirement before start: 
 - Harbor with proper CA Cert chain.
 - Have DNS A records to be added for *.tmc.corp.com and tmc.corp.com with pre-selected LB IP address.

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

For airgapped environments, run the ```00-prep.sh``` script.

Downloading required all packages.
```
$ ./00-prep.sh prep
```

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