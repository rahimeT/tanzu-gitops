#!/bin/bash

export harbor="harbor.example.com"

if test -f install.yaml; then
    echo "install.yaml exists."
else 
    wget "https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/install.yaml"
fi

for IMAGE in $(cat install.yaml|grep "image:"|sort -u|sed 's/ //g')
do
    IMG=${IMAGE#image:}
    NEW_IMG=$harbor/argo/$IMG
    echo "burasi "$IMG " " $NEW_IMG
    docker pull $IMG
    docker tag $IMG $harbor/argo/$IMG
    docker push $harbor/argo/$IMG
    sed -i -e "s~$IMG~$NEW_IMG~g" ./install.yaml
done

kubectl create ns argo-cd
kubectl apply -f install.yaml -n argo-cd
kubectl -n argo-cd patch svc argocd-server  -p '{"spec": {"type": "LoadBalancer"}}'
#kubectl -n argo-cd patch deployment argocd-redis -p '{"spec":{"template":{"spec":{"containers":[{"name":"redis","image":"harbor.dorn.gorke.ml/tools/redis:7.0.5-alpine"}]}}}}'
ARGO_PASS=$(kubectl -n argo-cd get secrets argocd-initial-admin-secret -o jsonpath='{.data.password}'|base64 -d)
ARGO_IP=$(kubectl -n argo-cd get svc argocd-server -o jsonpath="{.status.loadBalancer.ingress[0].ip}")

echo " "
echo "ARGO IP: " "https://"$ARGO_IP
echo "ARGO Admin: admin"
echo "ARGO PASS: " $ARGO_PASS
