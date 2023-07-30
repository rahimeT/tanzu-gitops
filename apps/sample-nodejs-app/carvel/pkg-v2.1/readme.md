# Quick Start for Airgapped Environments

Copy existing bundle to another container registry.
```
mkdir -p airgapped-files/images/
imgpkg copy -b projects.registry.vmware.com/tanzu_meta_pocs/packages/sample-app:2.1.0 --to-tar airgapped-files/images/sample-app-v2.1.tar --include-non-distributable-layers --concurrency 30
export IMGPKG_REGISTRY_HOSTNAME_0=harbor.corp.com
export IMGPKG_REGISTRY_USERNAME_0='admin'
export IMGPKG_REGISTRY_PASSWORD_0='VMware1!'
imgpkg copy --tar airgapped-files/images/sample-app-v2.1.tar --to-repo $IMGPKG_REGISTRY_HOSTNAME_0/apps/packages/sample-app --include-non-distributable-layers
```

# Deploy package

Create service account and roles for package deployment.

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    tkg.tanzu.vmware.com/tanzu-package: package-sample-app-package
    kapp.k14s.io/update-strategy: "fallback-on-replace"
  name: package-sample-app-package-sa
  namespace: packages
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    tkg.tanzu.vmware.com/tanzu-package: package-sample-app-package
    kapp.k14s.io/update-strategy: "fallback-on-replace"
  name: package-sample-app-package-cluster-role
rules:
- apiGroups:
  - '*'
  resources:
  - '*'
  verbs:
  - '*'
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  annotations:
    tkg.tanzu.vmware.com/tanzu-package: package-sample-app-package
    kapp.k14s.io/update-strategy: "fallback-on-replace"
  name: package-sample-app-package-cluster-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: package-sample-app-package-cluster-role
subjects:
- kind: ServiceAccount
  name: package-sample-app-package-sa
  namespace: packages
EOF
```

Create Package Repository for the package.

```
cat <<EOF | kubectl apply -f -
---
apiVersion: data.packaging.carvel.dev/v1alpha1
kind: Package
metadata:
  name: sample-app.corp.com.2.1.0
  namespace: packages
spec:
  refName: sample-app.corp.com
  version: 2.1.0
  releaseNotes: |
    Second release of the sample app package
  template:
    spec:
      fetch:
      - imgpkgBundle:
          image: ${IMGPKG_REGISTRY_HOSTNAME_0}/apps/packages/sample-app:2.1.0
      template:
      - ytt:
          paths:
          - config/
      - kbld:
          paths:
          - .imgpkg/images.yml
          - '-'
      deploy:
      - kapp: {}
EOF
```

Install Package via PackageInstall.

```
cat <<EOF | kubectl apply -f -
---
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageInstall
metadata:
  name: pkg-demo
  namespace: packages
  annotations:
    packaging.carvel.dev/downgradable: ""
spec:
  serviceAccountName: package-sample-app-package-sa
  packageRef:
    refName: sample-app.corp.com
    versionSelection:
      constraints: 2.1.0
  values:
  - secretRef:
      name: pkg-demo-values
---
apiVersion: v1
kind: Secret
metadata:
  name: pkg-demo-values
  namespace: packages
stringData:
  values.yml: |
    ---
    namespace: my-apps
    app:
      hello_message: Gorkem
      ingress_domain: "app.corp.com"
      ingress_class_name: ""
      service_type: LoadBalancer
      service_account: custom-service-account-name
      user: gorkem-user
      passw: gorkem-pass
EOF
```

# Step by Step from scratch

Create a config folder.
```
mkdir -p config/
```
Then,
- create app.yaml + values-schema.yaml + values.yaml to config directory.

And
- carvelize app.yaml

Create folder for imgpkg and lock existing images.
```
mkdir -p .imgpkg
kbld -f config/ --imgpkg-lock-output .imgpkg/images.yml
```
add metadata.yaml to ``packages/sample-app.corp.com/`` folder, so that it will have information for the package.

create schema-openapi.yaml, so that it will have information for applicible values.
```
ytt -f config/values-schema.yaml --data-values-schema-inspect -o openapi-v3 > /tmp/schema-openapi.yaml
```
push app bundle to container registry.
```
export IMGPKG_REGISTRY_HOSTNAME_0=harbor.corp.com
export IMGPKG_REGISTRY_USERNAME_0='admin'
export IMGPKG_REGISTRY_PASSWORD_0='VMware1!'
imgpkg push -b $IMGPKG_REGISTRY_HOSTNAME_0/apps/packages/sample-app:2.1.0 -f .
```
create package.yaml
```
cat > /tmp/package-template.yaml << EOF
#@ load("@ytt:data", "data")  # for reading data values (generated via ytt's data-values-schema-inspect mode).
#@ load("@ytt:yaml", "yaml")  # for dynamically decoding the output of ytt's data-values-schema-inspect
---
apiVersion: data.packaging.carvel.dev/v1alpha1
kind: Package
metadata:
  name: #@ "sample-app.corp.com." + data.values.version
spec:
  refName: sample-app.corp.com
  version: #@ data.values.version
  releaseNotes: |
        Initial release of the sample app package
  valuesSchema:
    openAPIv3: #@ yaml.decode(data.values.openapi)["components"]["schemas"]["dataValues"]
  template:
    spec:
      fetch:
      - imgpkgBundle:
          image: #@ data.values.harbor_fqdn + "/apps/packages/sample-app:" + data.values.version
      template:
      - ytt:
          paths:
          - "config/"
      - kbld:
          paths:
          - ".imgpkg/images.yml"
          - "-"
      deploy:
      - kapp: {}
EOF
```

```
ytt -f config/values.yaml --data-values-schema-inspect -o openapi-v3 > /tmp/schema-openapi.yaml

ytt -f /tmp/package-template.yaml --data-value-file openapi=/tmp/schema-openapi.yaml -v version="2.1.0" --data-value harbor_fqdn="$IMGPKG_REGISTRY_HOSTNAME_0" > packages/sample-app.corp.com/2.1.0.yaml
```
