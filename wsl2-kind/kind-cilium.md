# KinD Cilium Cluster

* [Getting Started Using Kind](https://docs.cilium.io/en/v1.13/gettingstarted/kind/)

* [Getting Started Guides » Quick Installation](https://docs.cilium.io/en/v1.13/gettingstarted/k8s-install-default/)

```shell
❯ cat <<EOF > kind-cilium.yaml
# kind-cilium.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true # disable kindnet
  podSubnet: "10.20.0.0/16"
  serviceSubnet: "10.21.0.0/16"
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

❯ kind create cluster --name cilium --config=kind-cilium.yaml

Creating cluster "cilium" ...
 ✓ Ensuring node image (kindest/node:v1.25.3) 🖼
 ✓ Preparing nodes 📦 📦 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-cilium"
You can now use your cluster with:

❯ kubectl cluster-info --context kind-cilium

Have a nice day! 👋

❯ kubectl cluster-info --context kind-cilium

Kubernetes control plane is running at https://127.0.0.1:46611
CoreDNS is running at https://127.0.0.1:46611/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

* Delete Cluster

```shell
❯ kind delete cluster --name cilium
```

## cilium

* [cilium client](https://github.com/cilium/cilium-cli/releases)

* Install Cilium CNI

```shell
❯ cilium install
🔮 Auto-detected Kubernetes kind: kind
✨ Running "kind" validation checks
✅ Detected kind version "0.17.0"
ℹ️  Using Cilium version 1.12.6
🔮 Auto-detected cluster name: kind-cilium
🔮 Auto-detected datapath mode: tunnel
🔮 Auto-detected kube-proxy has been installed
ℹ️  helm template --namespace kube-system cilium cilium/cilium --version 1.12.6 --set cluster.id=0,cluster.name=kind-cilium,encryption.nodeEncryption=false,ipam.mode=kubernetes,kubeProxyReplacement=disabled,operator.replicas=1,serviceAccounts.cilium.name=cilium,serviceAccounts.operator.name=cilium-operator,tunnel=vxlan
ℹ️  Storing helm values file in kube-system/cilium-cli-helm-values Secret
🔑 Created CA in secret cilium-ca
🔑 Generating certificates for Hubble...
🚀 Creating Service accounts...
🚀 Creating Cluster roles...
🚀 Creating ConfigMap for Cilium version 1.12.6...
🚀 Creating Agent DaemonSet...
🚀 Creating Operator Deployment...
⌛ Waiting for Cilium to be installed and ready...
✅ Cilium was successfully installed! Run 'cilium status' to view installation health

❯ cilium status
    /¯¯\
 /¯¯\__/¯¯\    Cilium:          OK
 \__/¯¯\__/    Operator:        OK
 /¯¯\__/¯¯\    Hubble Relay:    disabled
 \__/¯¯\__/    ClusterMesh:     disabled
    \__/

DaemonSet         cilium             Desired: 4, Ready: 4/4, Available: 4/4
Deployment        cilium-operator    Desired: 1, Ready: 1/1, Available: 1/1
Containers:       cilium             Running: 4
                  cilium-operator    Running: 1
Cluster Pods:     3/3 managed by Cilium
Image versions    cilium             quay.io/cilium/cilium:v1.12.6@sha256:454134506b0448c756398d3e8df68d474acde2a622ab58d0c7e8b272b5867d0d: 4
                  cilium-operator    quay.io/cilium/operator-generic:v1.12.6@sha256:eec4430d222cb2967d42d3b404d2606e66468de47ae85e0a3ca3f58f00a5e017: 1
```

## Enable Cilium Hubble

* [Setting up Hubble Observability](https://docs.cilium.io/en/v1.13/gettingstarted/hubble_setup/)
* [hubble client](https://github.com/cilium/hubble/releases)
* [Service Map & Hubble UI](https://docs.cilium.io/en/v1.13/gettingstarted/hubble/#hubble-ui)

```shell
❯ cilium hubble enable --ui
🔑 Found CA in secret cilium-ca
ℹ️  helm template --namespace kube-system cilium cilium/cilium --version 1.12.6 --set cluster.id=0,cluster.name=(...),tunnel=vxlan
✨ Patching ConfigMap cilium-config to enable Hubble...
🚀 Creating ConfigMap for Cilium version 1.12.6...
♻️  Restarted Cilium pods
⌛ Waiting for Cilium to become ready before deploying other Hubble component(s)...
🚀 Creating Peer Service...
✨ Generating certificates...
🔑 Generating certificates for Relay...
✨ Deploying Relay...
✨ Deploying Hubble UI and Hubble UI Backend...
⌛ Waiting for Hubble to be installed...
ℹ️  Storing helm values file in kube-system/cilium-cli-helm-values Secret
✅ Hubble was successfully enabled!

❯ cilium hubble ui
ℹ️  Opening "http://localhost:12000" in your browser...
```

* Hubble Extra

```shell
❯ cilium hubble port-forward

❯ hubble status
Healthcheck (via localhost:4245): Ok
Current/Max Flows: 1,819/16,380 (11.11%)
Flows/s: 9.53
Connected Nodes: 4/4

❯ hubble observe
Feb 17 13:16:43.650: 10.10.3.60:33530 (remote-node) <> 10.10.2.190:4240 (health) to-overlay FORWARDED (TCP Flags: ACK, PSH)
Feb 17 13:16:43.650: 10.10.3.60:33530 (remote-node) -> 10.10.2.190:4240 (health) to-endpoint FORWARDED (TCP Flags: ACK, PSH)
```

## starwars demo

* [starwars-demo](https://docs.cilium.io/en/v1.13/gettingstarted/demo/#starwars-demo)

```shell
❯ kubectl create -f https://raw.githubusercontent.com/cilium/cilium/v1.13/examples/minikube/http-sw-app.yaml
service/deathstar created
deployment.apps/deathstar created
pod/tiefighter created
pod/xwing created

❯ kubectl exec xwing -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
Ship landed

❯ kubectl exec tiefighter -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
Ship landed
```

* policy

```shell
❯ kubectl create -f https://raw.githubusercontent.com/cilium/cilium/v1.13/examples/minikube/sw_l3_l4_policy.yaml
```

* clean up

```shell
❯ kubectl delete -f https://raw.githubusercontent.com/cilium/cilium/v1.13/examples/minikube/http-sw-app.yaml

❯ kubectl delete cnp rule1
```

## nginx example

* nginx example

```shell
❯ kubectl create deployment nginx --image=nginx --port=80

❯ kubectl create service nodeport nginx --tcp=80:80 --node-port=30000

❯ curl localhost:30000

❯ kubectl delete service nginx

❯ kubectl delete deployment nginx
```
