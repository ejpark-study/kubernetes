# KinD with Flannel CNI

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
  extraMounts:
  - hostPath: /home/plugins/bin
    containerPath: /opt/cni/bin
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

❯ kind create cluster --name flannel --config=kind-flannel.yaml

❯ kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

❯ kubectl create deployment nwtest --image busybox --replicas 2 -- sleep infinity
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
