# Kubernete in Docker container

* [Install Docker on Windows (WSL) without Docker Desktop](https://dev.to/bowmanjd/install-docker-on-windows-wsl-without-docker-desktop-34m9)
* [Get started with Kubernetes in Docker (kind) in WSL2](https://gist.github.com/alexchiri/aca79caee89a33f0856951cedbf306dc)

## Install KinD

* [kind Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start)
* [kind/releases](https://github.com/kubernetes-sigs/kind/releases)

```shell
❯ sudo curl -Lo /usr/local/bin/kind https://github.com/kubernetes-sigs/kind/releases/download/v0.17.0/kind-linux-amd64

❯ sudo chmod +x /usr/local/bin/kind
```

* [Using WSL2](https://kind.sigs.k8s.io/docs/user/using-wsl2/)

```shell
❯ cat <<EOF > cluster-config.yaml
# cluster-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  podSubnet: "10.244.0.0/16"
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 30000
    hostPort: 30000
    protocol: TCP
- role: worker
- role: worker
- role: worker
EOF
```

* nginx test

```shell
❯ kind create cluster --name default --config=cluster-config.yaml

❯ kind delete cluster --name default

❯ kubectl create deployment nginx --image=nginx --port=80

❯ kubectl create service nodeport nginx --tcp=80:80 --node-port=30000

❯ kubectl create service loadbalancer nginx --tcp=80:80 

❯ curl localhost:30000
```

# MetalLB

```shell
❯ kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
namespace/metallb-system created
customresourcedefinition.apiextensions.k8s.io/addresspools.metallb.io created
customresourcedefinition.apiextensions.k8s.io/bfdprofiles.metallb.io created
customresourcedefinition.apiextensions.k8s.io/bgpadvertisements.metallb.io created
customresourcedefinition.apiextensions.k8s.io/bgppeers.metallb.io created
customresourcedefinition.apiextensions.k8s.io/communities.metallb.io created
customresourcedefinition.apiextensions.k8s.io/ipaddresspools.metallb.io created
customresourcedefinition.apiextensions.k8s.io/l2advertisements.metallb.io created
serviceaccount/controller created
serviceaccount/speaker created
role.rbac.authorization.k8s.io/controller created
role.rbac.authorization.k8s.io/pod-lister created
clusterrole.rbac.authorization.k8s.io/metallb-system:controller created
clusterrole.rbac.authorization.k8s.io/metallb-system:speaker created
rolebinding.rbac.authorization.k8s.io/controller created
rolebinding.rbac.authorization.k8s.io/pod-lister created
clusterrolebinding.rbac.authorization.k8s.io/metallb-system:controller created
clusterrolebinding.rbac.authorization.k8s.io/metallb-system:speaker created
secret/webhook-server-cert created
service/webhook-service created
deployment.apps/controller created
daemonset.apps/speaker created
validatingwebhookconfiguration.admissionregistration.k8s.io/metallb-webhook-configuration created

❯ kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=90s
pod/controller-84d6d4db45-8qnwh condition met
pod/speaker-9pmvd condition met
pod/speaker-jb7ft condition met
pod/speaker-l2kcw condition met
pod/speaker-zkcdm condition met

❯ docker network ls
NETWORK ID     NAME      DRIVER    SCOPE
fece29f06fdc   bridge    bridge    local
9eb2b6e1e351   host      host      local
e2f8fbe8972c   kind      bridge    local
50febaf83e1c   none      null      local

❯ docker network inspect -f '{{.IPAM.Config}}' kind
[{10.11.0.0/24  10.11.0.1 map[]} {fc00:f853:ccd:e793::/64   map[]}]

❯ kubectl apply -f https://kind.sigs.k8s.io/examples/loadbalancer/metallb-config.yaml

❯ wget https://kind.sigs.k8s.io/examples/loadbalancer/metallb-config.yaml

❯ kubectl apply -f https://kind.sigs.k8s.io/examples/loadbalancer/usage.yaml

LB_IP=$(kubectl get svc/foo-service -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')

for _ in {1..10}; do
  curl ${LB_IP}:5678
done
```

# metrics server

* [Running metric-server on Kind Kubernetes](https://gist.github.com/sanketsudake/a089e691286bf2189bfedf295222bd43)

* [Kubernetes Metrics Server | How to deploy k8s metrics server and use it for monitoring](https://signoz.io/blog/kubernetes-metrics-server/)

```shell
# kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# kubectl edit deployments.apps -n kube-system metrics-server

# --kubelet-insecure-tls=true
# --requestheader-client-ca-file
```

```shell
❯ kubectl apply -f metrics-server.yaml
serviceaccount/metrics-server created
clusterrole.rbac.authorization.k8s.io/system:aggregated-metrics-reader created
clusterrole.rbac.authorization.k8s.io/system:metrics-server created
rolebinding.rbac.authorization.k8s.io/metrics-server-auth-reader created
clusterrolebinding.rbac.authorization.k8s.io/metrics-server:system:auth-delegator created
clusterrolebinding.rbac.authorization.k8s.io/system:metrics-server created
service/metrics-server created
deployment.apps/metrics-server created
apiservice.apiregistration.k8s.io/v1beta1.metrics.k8s.io created
```

* [K8S Cluster with Flannel CNI using KinD](https://routemyip.com/posts/k8s/setup/flannel/)

```shell
❯ git clone https://github.com/containernetworking/plugins.git

❯ cd plugins && ./build_linux.sh

❯ cat <<EOF > kind-flannel.yaml
# kind-flannel.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true # disable kindnet
  podSubnet: "10.244.0.0/16"
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 30000
    hostPort: 30000
    protocol: TCP
- role: worker
- role: worker
- role: worker
EOF

# - role: control-plane
#   extraMounts:
#   - hostPath: /home/plugins/bin
#     containerPath: /opt/cni/bin

❯ kind create cluster --name cilium --config=kind-cilium.yaml

❯ kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

❯ kubectl create deployment nwtest --image busybox --replicas 2 -- sleep infinity
```
