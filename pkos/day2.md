**"24단계 실습으로 정복하는 쿠버네티스" 책을 기준하여 정리하였습니다.**

# 2주차 - 네트워크 & 스토리지

![](images/pkos-2.png)

## 실습 클러스터 생성

```shell
❯ git clone https://github.com/gasida/PKOS.git pkos
Cloning into 'pkos'...
remote: Enumerating objects: 74, done.
remote: Counting objects: 100% (74/74), done.
remote: Compressing objects: 100% (57/57), done.
remote: Total 74 (delta 16), reused 68 (delta 10), pack-reused 0
Receiving objects: 100% (74/74), 9.85 KiB | 1.41 MiB/s, done.
Resolving deltas: 100% (16/16), done.

# Set Env.
❯ export ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
❯ export KOPS_CLUSTER_NAME=ejpark.link
❯ export KOPS_STATE_STORE=s3://koala-k8s-s3

# https://towardsthecloud.com/aws-cli-empty-s3-bucket
# aws s3 rm s3://koala-k8s-s3 --recursive
# aws s3 rb s3://koala-k8s-s3

# S3 State Store Bucket Name
❯ aws s3 mb $KOPS_STATE_STORE --region ap-northeast-2
make_bucket: koala-k8s-s3

❯ aws s3 ls
2023-03-18 08:59:55 koala-k8s-s3

# Create kOps template
❯ kops create cluster \
    --zones=ap-northeast-2a,ap-northeast-2c \
    --networking amazonvpc \
    --cloud aws \
    --master-size t3.medium \
    --node-size t3.medium \
    --node-count=2 \
    --network-cidr 172.30.0.0/16 \
    --ssh-public-key ~/.ssh/id_rsa.pub \
    --kubernetes-version "1.24.11" \
    --dry-run \
    --output yaml \
    --state=$KOPS_STATE_STORE \
    --name=$KOPS_CLUSTER_NAME \
    > kops.yaml
I0318 09:04:03.533182    1097 create_cluster.go:831] Using SSH public key: /home/ubuntu/.ssh/id_rsa.pub
I0318 09:04:06.386108    1097 new_cluster.go:1279]  Cloud Provider ID = aws
I0318 09:04:06.542050    1097 subnets.go:185] Assigned CIDR 172.30.32.0/19 to subnet ap-northeast-2a
I0318 09:04:06.542165    1097 subnets.go:185] Assigned CIDR 172.30.64.0/19 to subnet ap-northeast-2c

# kOps Addon
❯ cat <<EOF > addon.yaml
  certManager:
    enabled: true
  awsLoadBalancerController:
    enabled: true
  externalDns:
    provider: external-dns
  metricsServer:
    enabled: true
  kubeProxy:
    metricsBindAddress: 0.0.0.0
  kubeDNS:
    provider: CoreDNS
    nodeLocalDNS:
      enabled: true
      memoryRequest: 5Mi
      cpuRequest: 25m
EOF
❯ sed -i -n -e '/aws$/r addon.yaml' -e '1,$p' kops.yaml

# max-pod per node
❯ cat <<EOF > maxpod.yaml
  maxPods: 100
EOF
❯ sed -i -n -e '/anonymousAuth/r maxpod.yaml' -e '1,$p' kops.yaml

# Change awsvpc: amazonvpc: {}
❯ sed -i 's/amazonvpc: {}/amazonvpc:/g' kops.yaml

❯ cat <<EOF > awsvpc.yaml
      env:
      - name: ENABLE_PREFIX_DELEGATION
      value: "true"
EOF
❯ sed -i -n -e '/amazonvpc/r awsvpc.yaml' -e '1,$p' kops.yaml

# Create kOps cluster
❯ kops create -f kops.yaml

Created cluster/ejpark.link
Created instancegroup/master-ap-northeast-2a
Created instancegroup/nodes-ap-northeast-2a
Created instancegroup/nodes-ap-northeast-2c

To deploy these resources, run: kops update cluster --name ejpark.link --yes

❯ kops update cluster --name $KOPS_CLUSTER_NAME --yes

*********************************************************************************

A new kops version is available: 1.26.2
Upgrading is recommended
More information: https://github.com/kubernetes/kops/blob/master/permalinks/upgrade_kops.md#1.26.2

*********************************************************************************

W0318 11:47:18.427249    2310 builder.go:231] failed to digest image "602401143452.dkr.ecr.us-west-2.amazonaws.com/amazon-k8s-cni:v1.11.4"
W0318 11:47:18.933451    2310 builder.go:231] failed to digest image "602401143452.dkr.ecr.us-west-2.amazonaws.com/amazon-k8s-cni-init:v1.11.4"
I0318 11:47:22.341213    2310 executor.go:111] Tasks: 0 done / 106 total; 51 can run
W0318 11:47:22.344584    2310 vfs_castore.go:382] CA private key was not found
W0318 11:47:22.344681    2310 vfs_castore.go:382] CA private key was not found
I0318 11:47:22.344878    2310 keypair.go:225] Issuing new certificate: "etcd-peers-ca-events"
I0318 11:47:22.344921    2310 keypair.go:225] Issuing new certificate: "kubernetes-ca"
I0318 11:47:22.344939    2310 keypair.go:225] Issuing new certificate: "etcd-clients-ca"
I0318 11:47:22.344894    2310 keypair.go:225] Issuing new certificate: "service-account"
I0318 11:47:22.344894    2310 keypair.go:225] Issuing new certificate: "apiserver-aggregator-ca"
I0318 11:47:22.344973    2310 keypair.go:225] Issuing new certificate: "etcd-manager-ca-events"
I0318 11:47:22.345048    2310 keypair.go:225] Issuing new certificate: "etcd-manager-ca-main"
I0318 11:47:22.344861    2310 keypair.go:225] Issuing new certificate: "etcd-peers-ca-main"
I0318 11:47:23.419986    2310 executor.go:111] Tasks: 51 done / 106 total; 21 can run
I0318 11:47:24.358758    2310 executor.go:111] Tasks: 72 done / 106 total; 28 can run
I0318 11:47:25.281701    2310 executor.go:111] Tasks: 100 done / 106 total; 3 can run
I0318 11:47:26.197688    2310 executor.go:155] No progress made, sleeping before retrying 3 task(s)
I0318 11:47:36.198974    2310 executor.go:111] Tasks: 100 done / 106 total; 3 can run
I0318 11:47:37.411401    2310 executor.go:111] Tasks: 103 done / 106 total; 3 can run
I0318 11:47:37.545426    2310 executor.go:111] Tasks: 106 done / 106 total; 0 can run
I0318 11:47:38.723745    2310 dns.go:238] Pre-creating DNS records
I0318 11:47:39.264891    2310 update_cluster.go:326] Exporting kubeconfig for cluster
kOps has set your kubectl context to ejpark.link
W0318 11:47:39.273742    2310 update_cluster.go:350] Exported kubeconfig with no user authentication; use --admin, --user or --auth-plugin flags with `kops export kubeconfig`

Cluster is starting.  It should be ready in a few minutes.

Suggestions:
 * validate cluster: kops validate cluster --wait 10m
 * list nodes: kubectl get nodes --show-labels
 * ssh to the master: ssh -i ~/.ssh/id_rsa ubuntu@api.ejpark.link
 * the ubuntu user is specific to Ubuntu. If not using Ubuntu please use the appropriate user based on your OS.
 * read about installing addons at: https://kops.sigs.k8s.io/addons.

❯ kops validate cluster --wait 10m
Validating cluster ejpark.link

W0318 14:09:16.038580    5115 validate_cluster.go:184] (will retry): unexpected error during validation: unable to resolve Kubernetes cluster API URL dns: lookup api.ejpark.link on 172.29.64.1:53: no such host

# kops create secret --name $KOPS_CLUSTER_NAME sshpublickey admin -i ~/.ssh/id_rsa.pub
❯ kops update cluster --name $KOPS_CLUSTER_NAME --ssh-public-key ~/.ssh/id_rsa.pub --yes
--ssh-public-key on update is deprecated - please use `kops create secret --name ejpark.link sshpublickey admin -i ~/.ssh/id_rsa.pub` instead
I0318 11:48:16.258058    2412 update_cluster.go:241] Using SSH public key: /home/ubuntu/.ssh/id_rsa.pub

W0318 11:48:29.908150    2412 builder.go:231] failed to digest image "602401143452.dkr.ecr.us-west-2.amazonaws.com/amazon-k8s-cni-init:v1.11.4"
W0318 11:48:30.435485    2412 builder.go:231] failed to digest image "602401143452.dkr.ecr.us-west-2.amazonaws.com/amazon-k8s-cni:v1.11.4"
I0318 11:48:34.465932    2412 executor.go:111] Tasks: 0 done / 107 total; 52 can run
I0318 11:48:35.449414    2412 executor.go:111] Tasks: 52 done / 107 total; 21 can run
I0318 11:48:36.251830    2412 executor.go:111] Tasks: 73 done / 107 total; 28 can run
I0318 11:48:37.124987    2412 executor.go:111] Tasks: 101 done / 107 total; 3 can run
I0318 11:48:37.254198    2412 executor.go:111] Tasks: 104 done / 107 total; 3 can run
I0318 11:48:37.385329    2412 executor.go:111] Tasks: 107 done / 107 total; 0 can run
I0318 11:48:38.313701    2412 update_cluster.go:326] Exporting kubeconfig for cluster
kOps has set your kubectl context to ejpark.link
W0318 11:48:38.315964    2412 update_cluster.go:350] Exported kubeconfig with no user authentication; use --admin, --user or --auth-plugin flags with `kops export kubeconfig`

Cluster changes have been applied to the cloud.

Changes may require instances to restart: kops rolling-update cluster

# kops kubeconfig
❯ kops export kubeconfig --admin
kOps has set your kubectl context to ejpark.link

# WSL
❯ dig ns api.ejpark.link
; <<>> DiG 9.18.1-1ubuntu1.3-Ubuntu <<>> ns api.ejpark.link
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 23065
;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 0, ADDITIONAL: 0

;; QUESTION SECTION:
;api.ejpark.link.               IN      NS

;; Query time: 0 msec
;; SERVER: 172.29.64.1#53(172.29.64.1) (UDP)
;; WHEN: Sat Mar 18 11:57:38 KST 2023
;; MSG SIZE  rcvd: 33

# EC2 instance profiles 에 IAM Policy 추가(attach) : 처음 입력 시 적용이 잘 안될 경우 다시 한번 더 입력 하자! - IAM Role에서 새로고침 먼저 확인!
❯ aws iam attach-role-policy --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy --role-name masters.$KOPS_CLUSTER_NAME

An error occurred (NoSuchEntity) when calling the AttachRolePolicy operation: Policy arn:aws:iam::*****:policy/AWSLoadBalancerControllerIAMPolicy does not exist or is not attachable.

❯ aws iam attach-role-policy --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy --role-name nodes.$KOPS_CLUSTER_NAME

An error occurred (NoSuchEntity) when calling the AttachRolePolicy operation: Policy arn:aws:iam::*****:policy/AWSLoadBalancerControllerIAMPolicy does not exist or is not attachable.
```

저는 WSL 에서 api.$KOPS_CLUSTER_NAME 로 접속이 안됬습니다.

![](images/2023-03-18-12-01-50.png)

kubeconfig 를 api.ejpark.link IP 로 수정해서 접속했는데도 안됬습니다.

```shell
❯ grep server ~/.kube/config
    server: https://ejpark.link

❯ grep server ~/.kube/config
    server: https://203.0.113.123

❯ kubectl get nodes -o wide
E0318 12:02:53.935950    3877 memcache.go:238] couldn't get current server API group list: Get "https://203.0.113.123/api?timeout=32s": dial tcp 203.0.113.123:443: connect: connection refused

(...)
```

## 실습 환경 배포

```shell
❯ export MyIamUserAccessKeyID=****
❯ export MyIamUserSecretAccessKey=***

❯ export ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
❯ export KOPS_CLUSTER_NAME=ejpark.link
❯ export KOPS_STATE_STORE=s3://koala-k8s-s3

# S3 State Store Bucket Name
❯ aws s3 ls
2023-03-18 14:07:41 koala-k8s-s3

# YAML 파일 다운로드
❯ curl -O https://s3.ap-northeast-2.amazonaws.com/cloudformation.cloudneta.net/K8S/kops-oneclick-f1.yaml

# CloudFormation 스택 배포 : 노드 인스턴스 타입 변경 - MasterNodeInstanceType=t3.medium WorkerNodeInstanceType=c5d.large
❯ aws cloudformation deploy \
    --stack-name mykops \
    --template-file kops-oneclick-f1.yaml \
    --region ap-northeast-2 \
    --parameter-overrides \
        KeyName=pkos \
        SgIngressSshCidr=$(curl -s ipinfo.io/ip)/32  \
        MyIamUserAccessKeyID=$MyIamUserAccessKeyID \
        MyIamUserSecretAccessKey="$MyIamUserSecretAccessKey" \
        ClusterBaseName=$KOPS_CLUSTER_NAME \
        S3StateStore='koala-k8s-s3' \
        MasterNodeInstanceType=t3.medium \
        WorkerNodeInstanceType=c5d.large

Waiting for changeset to be created..
Waiting for stack create/update to complete
Successfully created/updated stack - mykops

❯ aws cloudformation describe-stack-events --stack-name mykops | grep ''
(...)
STACKEVENTS     12d3b380-c5e5-11ed-b37b-024c24fb20d6    mykops  arn:aws:cloudformation:ap-northeast-2:131654622386:stack/mykops/0f745be0-c5e5-11ed-89c5-0a9e9e96b94c            CREATE_IN_PROGRESS      User Initiated  AWS::CloudFormation::Stack      arn:aws:cloudformation:ap-northeast-2:131654622386:stack/mykops/0f745be0-c5e5-11ed-89c5-0a9e9e96b94c    mykops  2023-03-18T23:31:57.220000+00:00
STACKEVENTS     0f73e6b0-c5e5-11ed-89c5-0a9e9e96b94c    mykops  arn:aws:cloudformation:ap-northeast-2:131654622386:stack/mykops/0f745be0-c5e5-11ed-89c5-0a9e9e96b94c            REVIEW_IN_PROGRESS      User Initiated  AWS::CloudFormation::Stack      arn:aws:cloudformation:ap-northeast-2:131654622386:stack/mykops/0f745be0-c5e5-11ed-89c5-0a9e9e96b94c    mykops  2023-03-18T23:31:51.757000+00:00

# CloudFormation 스택 배포 완료 후 kOps EC2 IP 출력
❯ aws cloudformation describe-stacks --stack-name mykops --query 'Stacks[*].Outputs[0].OutputValue' --output text | grep ''
43.201.70.158

# 13분 후 작업 SSH 접속
❯ ssh -i ~/.ssh/pkos.pem ec2-user@$(aws cloudformation describe-stacks --stack-name mykops --query 'Stacks[*].Outputs[0].OutputValue' --output text)
X11 forwarding request failed on channel 0

       __|  __|_  )
       _|  (     /   Amazon Linux 2 AMI
      ___|\___|___|

https://aws.amazon.com/amazon-linux-2/
W0319 08:35:27.660390    3239 vfs_castore.go:383] CA private key was not found
Error: cannot find CA certificate
kOps has set your kubectl context to ejpark.link

# AWSLoadBalancerController IAM 정책 생성 : 이미 정책이 있다면 Skip~
(ejpark:N/A) [root@kops-ec2 ~]# curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.5/docs/install/iam_policy.json
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  7617  100  7617    0     0   254k      0 --:--:-- --:--:-- --:--:--  247k

(ejpark:N/A) [root@kops-ec2 ~]# aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json
{
    "Policy": {
        "PolicyName": "AWSLoadBalancerControllerIAMPolicy",
        "PolicyId": "*****",
        "Arn": "arn:aws:iam::131654622386:policy/AWSLoadBalancerControllerIAMPolicy",
        "Path": "/",
        "DefaultVersionId": "v1",
        "AttachmentCount": 0,
        "PermissionsBoundaryUsageCount": 0,
        "IsAttachable": true,
        "CreateDate": "2023-03-18T23:36:18+00:00",
        "UpdateDate": "2023-03-18T23:36:18+00:00"
    }
}

# EC2 instance profiles 에 IAM Policy 추가(attach) : 처음 입력 시 적용이 잘 안될 경우 다시 한번 더 입력 하자! - IAM Role에서 새로고침 먼저 확인!
(ejpark:N/A) [root@kops-ec2 ~]# aws iam attach-role-policy --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy --role-name masters.$KOPS_CLUSTER_NAME
(ejpark:N/A) [root@kops-ec2 ~]# aws iam attach-role-policy --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy --role-name nodes.$KOPS_CLUSTER_NAME

(ejpark:N/A) [root@kops-ec2 ~]# kops update cluster --name ejpark.link --yes

*********************************************************************************

A new kubernetes version is available: 1.24.12
Upgrading is recommended (try kops upgrade cluster)

More information: https://github.com/kubernetes/kops/blob/master/permalinks/upgrade_k8s.md#1.24.12

*********************************************************************************

W0319 08:42:49.223655    4431 builder.go:230] failed to digest image "602401143452.dkr.ecr.us-west-2.amazonaws.com/amazon-k8s-cni:v1.12.2"
W0319 08:42:49.704316    4431 builder.go:230] failed to digest image "602401143452.dkr.ecr.us-west-2.amazonaws.com/amazon-k8s-cni-init:v1.12.2"
I0319 08:42:53.211318    4431 executor.go:111] Tasks: 0 done / 107 total; 52 can run
I0319 08:42:54.115102    4431 executor.go:111] Tasks: 52 done / 107 total; 21 can run
I0319 08:42:55.031196    4431 executor.go:111] Tasks: 73 done / 107 total; 28 can run
I0319 08:42:55.301227    4431 executor.go:111] Tasks: 101 done / 107 total; 3 can run
I0319 08:42:55.413309    4431 executor.go:111] Tasks: 104 done / 107 total; 3 can run
I0319 08:42:55.472309    4431 executor.go:111] Tasks: 107 done / 107 total; 0 can run
I0319 08:42:56.242161    4431 update_cluster.go:323] Exporting kubeconfig for cluster
kOps has set your kubectl context to ejpark.link
W0319 08:42:56.243966    4431 update_cluster.go:347] Exported kubeconfig with no user authentication; use --admin, --user or --auth-plugin flags with `kops export kubeconfig`

Cluster changes have been applied to the cloud.


Changes may require instances to restart: kops rolling-update cluster

(ejpark:N/A) [root@kops-ec2 ~]# kops validate cluster --wait 10m
Validating cluster ejpark.link

INSTANCE GROUPS
NAME                    ROLE            MACHINETYPE     MIN     MAX     SUBNETS
master-ap-northeast-2a  ControlPlane    t3.medium       1       1       ap-northeast-2a
nodes-ap-northeast-2a   Node            t3.medium       1       1       ap-northeast-2a
nodes-ap-northeast-2c   Node            t3.medium       1       1       ap-northeast-2c

NODE STATUS
NAME    ROLE    READY

VALIDATION ERRORS
KIND    NAME            MESSAGE
dns     apiserver       Validation Failed

The external-dns Kubernetes deployment has not updated the Kubernetes cluster's API DNS entry to the correct IP address.  The API DNS IP address is the placeholder address that kops creates: 203.0.113.123.  Please wait about 5-10 minutes for a control plane node to start, external-dns to launch, and DNS to propagate.  The protokube container and external-dns deployment logs may contain more diagnostic information.  Etcd and the API DNS entries must be updated for a kops Kubernetes cluster to start.

Validation Failed
W0319 08:43:20.239509    4570 validate_cluster.go:232] (will retry): cluster not yet healthy
(...)
```

> "Validation Failed"가 반복된다. 아래와 같이 삭제후 1주차 방식으로 배포해 보려고 합니다.

```shell
❯ kops delete cluster --yes 

❯ aws cloudformation delete-stack --stack-name mykops

❯ aws s3 rm s3://koala-k8s-s3 --recursive
delete: s3://koala-k8s-s3/ejpark.link/instancegroup/nodes-ap-northeast-2a
delete: s3://koala-k8s-s3/ejpark.link/config
delete: s3://koala-k8s-s3/ejpark.link/instancegroup/nodes-ap-northeast-2c
delete: s3://koala-k8s-s3/ejpark.link/instancegroup/master-ap-northeast-2a

❯ aws s3 rb s3://koala-k8s-s3
remove_bucket: koala-k8s-s3
```

## 3차 시도

```shell
❯ export AWS_PAGER=""
❯ export REGION=ap-northeast-2
❯ export KOPS_CLUSTER_NAME=ejpark.link
❯ export KOPS_STATE_STORE=s3://koala-k8s-s3

❯ kops create cluster \
    --zones="$REGION"a,"$REGION"c \
    --networking amazonvpc \
    --cloud aws \
    --master-size t3.medium \
    --node-size t3.medium \
    --node-count=2 \
    --network-cidr 172.30.0.0/16 \
    --ssh-public-key ~/.ssh/id_rsa.pub \
    --name=$KOPS_CLUSTER_NAME \
    --kubernetes-version "1.24.11"

I0319 08:55:51.121388    7080 create_cluster.go:831] Using SSH public key: /home/ubuntu/.ssh/id_rsa.pub
I0319 08:55:52.954208    7080 new_cluster.go:1279]  Cloud Provider ID = aws
I0319 08:55:53.113428    7080 subnets.go:185] Assigned CIDR 172.30.32.0/19 to subnet ap-northeast-2a
I0319 08:55:53.113524    7080 subnets.go:185] Assigned CIDR 172.30.64.0/19 to subnet ap-northeast-2c
Previewing changes that will be made:

(...)

Must specify --yes to apply changes

Cluster configuration has been created.

Suggestions:
 * list clusters with: kops get cluster
 * edit this cluster with: kops edit cluster ejpark.link
 * edit your node instance group: kops edit ig --name=ejpark.link nodes-ap-northeast-2a
 * edit your master instance group: kops edit ig --name=ejpark.link master-ap-northeast-2a

Finally configure your cluster with: kops update cluster --name ejpark.link --yes --admin

❯ kops update cluster --name ejpark.link --yes --admin

W0319 08:57:44.712972    7118 builder.go:231] failed to digest image "602401143452.dkr.ecr.us-west-2.amazonaws.com/amazon-k8s-cni:v1.11.4"
W0319 08:57:45.252895    7118 builder.go:231] failed to digest image "602401143452.dkr.ecr.us-west-2.amazonaws.com/amazon-k8s-cni-init:v1.11.4"
I0319 08:57:49.086083    7118 executor.go:111] Tasks: 0 done / 103 total; 48 can run
W0319 08:57:49.292109    7118 vfs_castore.go:382] CA private key was not found
I0319 08:57:49.299892    7118 keypair.go:225] Issuing new certificate: "etcd-manager-ca-events"
I0319 08:57:49.310710    7118 keypair.go:225] Issuing new certificate: "etcd-manager-ca-main"
I0319 08:57:49.312066    7118 keypair.go:225] Issuing new certificate: "apiserver-aggregator-ca"
I0319 08:57:49.312181    7118 keypair.go:225] Issuing new certificate: "etcd-peers-ca-main"
I0319 08:57:49.323876    7118 keypair.go:225] Issuing new certificate: "etcd-peers-ca-events"
I0319 08:57:49.331981    7118 keypair.go:225] Issuing new certificate: "etcd-clients-ca"
W0319 08:57:49.348115    7118 vfs_castore.go:382] CA private key was not found
I0319 08:57:49.364170    7118 keypair.go:225] Issuing new certificate: "kubernetes-ca"
I0319 08:57:49.381745    7118 keypair.go:225] Issuing new certificate: "service-account"
I0319 08:57:50.184467    7118 executor.go:111] Tasks: 48 done / 103 total; 21 can run
I0319 08:57:51.293230    7118 executor.go:111] Tasks: 69 done / 103 total; 28 can run
I0319 08:57:52.460280    7118 executor.go:111] Tasks: 97 done / 103 total; 3 can run
I0319 08:57:53.388968    7118 executor.go:155] No progress made, sleeping before retrying 3 task(s)
I0319 08:58:03.390630    7118 executor.go:111] Tasks: 97 done / 103 total; 3 can run
I0319 08:58:04.646868    7118 executor.go:111] Tasks: 100 done / 103 total; 3 can run
I0319 08:58:04.783624    7118 executor.go:111] Tasks: 103 done / 103 total; 0 can run
I0319 08:58:05.962512    7118 dns.go:238] Pre-creating DNS records
I0319 08:58:06.414001    7118 update_cluster.go:326] Exporting kubeconfig for cluster
kOps has set your kubectl context to ejpark.link

Cluster is starting.  It should be ready in a few minutes.

Suggestions:
 * validate cluster: kops validate cluster --wait 10m
 * list nodes: kubectl get nodes --show-labels
 * ssh to the master: ssh -i ~/.ssh/id_rsa ubuntu@api.ejpark.link
 * the ubuntu user is specific to Ubuntu. If not using Ubuntu please use the appropriate user based on your OS.
 * read about installing addons at: https://kops.sigs.k8s.io/addons.

 ❯ aws ec2 describe-instances --query "Reservations[*].Instances[*].{PublicIPAdd:PublicIpAddress,PrivateIPAdd:PrivateIpAddress,InstanceName:Tags[?Key=='Name']|[0].Value,Status:State.Name}" --filters Name=instance-state-name,Values=running --output table | grep ''
---------------------------------------------------------------------------------------------
|                                     DescribeInstances                                     |
+---------------------------------------------+----------------+----------------+-----------+
|                InstanceName                 | PrivateIPAdd   |  PublicIPAdd   |  Status   |
+---------------------------------------------+----------------+----------------+-----------+
|  nodes-ap-northeast-2c.ejpark.link          |  172.30.77.200 |  43.201.25.172 |  running  |
|  master-ap-northeast-2a.masters.ejpark.link |  172.30.47.189 |  3.36.26.76    |  running  |
|  nodes-ap-northeast-2a.ejpark.link          |  172.30.62.109 |  52.78.13.229  |  running  |
+---------------------------------------------+----------------+----------------+-----------+

❯ ssh -i ~/.ssh/id_rsa ubuntu@3.36.26.76
Welcome to Ubuntu 20.04.5 LTS (GNU/Linux 5.15.0-1031-aws x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Sun Mar 19 00:01:18 UTC 2023

  System load:  1.14              Processes:             166
  Usage of /:   8.6% of 61.84GB   Users logged in:       0
  Memory usage: 25%               IPv4 address for ens5: 172.30.47.189
  Swap usage:   0%

(...)

ubuntu@i-0ad86f23f13499914:~$ kubectl get pod -A
NAMESPACE     NAME                                          READY   STATUS              RESTARTS       AGE
kube-system   aws-cloud-controller-manager-dzbcm            1/1     Running             0              87s
kube-system   aws-node-b2xrp                                1/1     Running             0              87s
kube-system   aws-node-h5ltq                                1/1     Running             0              28s
kube-system   aws-node-rpvlm                                1/1     Running             0              34s
kube-system   coredns-6897c49dc4-qlrck                      0/1     ContainerCreating   0              87s
kube-system   coredns-autoscaler-5685d4f67b-9kd6c           0/1     ContainerCreating   0              87s
kube-system   dns-controller-844ddc7657-sw79t               1/1     Running             0              87s
kube-system   ebs-csi-controller-776c4cfdf6-cr5wc           5/5     Running             0              87s
kube-system   ebs-csi-node-55nxx                            0/3     ContainerCreating   0              28s
kube-system   ebs-csi-node-h4gmp                            3/3     Running             0              87s
kube-system   ebs-csi-node-hv2j2                            0/3     ContainerCreating   0              34s
kube-system   etcd-manager-events-i-0ad86f23f13499914       1/1     Running             0              71s
kube-system   etcd-manager-main-i-0ad86f23f13499914         1/1     Running             0              74s
kube-system   kops-controller-xlhws                         1/1     Running             0              87s
kube-system   kube-apiserver-i-0ad86f23f13499914            2/2     Running             0              45s
kube-system   kube-controller-manager-i-0ad86f23f13499914   1/1     Running             2 (2m1s ago)   101s
kube-system   kube-proxy-i-0ad86f23f13499914                1/1     Running             0              64s
kube-system   kube-scheduler-i-0ad86f23f13499914            1/1     Running             0              54s

❯ kops validate cluster --wait 10m
Validating cluster ejpark.link

INSTANCE GROUPS
NAME                    ROLE    MACHINETYPE     MIN     MAX     SUBNETS
master-ap-northeast-2a  Master  t3.medium       1       1       ap-northeast-2a
nodes-ap-northeast-2a   Node    t3.medium       1       1       ap-northeast-2a
nodes-ap-northeast-2c   Node    t3.medium       1       1       ap-northeast-2c

NODE STATUS
NAME                    ROLE    READY
i-01cadf0d8d3c7a565     node    True
i-0ad86f23f13499914     master  True
i-0f395f78142396d9d     node    True

Your cluster ejpark.link is ready
```

1주차 방식으로 배포했더니, 이와 같이 실행되었습니다. 2주차의 addon 이나 network 플러그인 설정부분에서 local desktop 에서 접근을 제한하는 설정이 들어갔었거나, 배포가 늦어져서 클러스터 생성전에 접근을 시도했었던 것 같습니다.

## 쿠버네티스 네트워크

1. AWS VPC CNI 소개

쿠버네티스 클러스터 내부에서 통신이 가능하게 해주는 CNI (Container Network Interface) 가 있다. 상황에 따라 여러 [CNI 플러그인](https://kubernetes.io/docs/concepts/cluster-administration/addons/#networking-and-network-policy)을 교체해서 사용할 수 있다. 나는 처음 쿠버네티스를 접했을 때, 제일 당황스러웠다. 리눅스처럼 생각했었던 나는 설치하고 네트워크 통신이 안되는 것을 보고 무척이나 당황했었다. 두번째로 당황스러웠던 것은 외부에서 컨테이너로 접속이 안되는 것이였다. 이 두가지 모두가 직/간접적으로 CNI 에 있었다.

> "AWS VPC CNI는 파드의 IP 네트워크 대역과 노드(워커)의 IP 대역이 같아서 직접 통신이 가능하다"는 특징이 있다고 한다.

이 부분이 좀 신기한 경험이였다. "어떻게?" 쿠버네티스 클러스터를 생성할때 POD IP 와 SERVICE IP 를 다른 대역대로 설정한다든지 한다. 그런데 이 POD IP 를 대역 (예: 172.30.0.0/16)으로 설정했는데, 노드 IP 대역대와 같은 것을 쓴다고? 내무 메커니즘이야 어떻게 되었든 신기하긴 하다.

![](images/2023-03-18-08-40-10.png)
> 그림 출처: [CloudNet@ Blog](https://gasidaseo.notion.site/AWS-EKS-VPC-CNI-1-POD-f89e3e5967b24f8c9aa5bfaab1a82ceb)

IP 대역대가 같으면, 일반 클러스터에서는 파드간 통신에서 오버레이 통신을 하는데 반해 AWS VPC CNI 는 동일 대역으로 직접 통신이 가능하다고 한다.

![](images/2023-03-18-08-41-16.png)
> 그림 출처: [CloudNet@ Blog](https://gasidaseo.notion.site/AWS-EKS-VPC-CNI-1-POD-f89e3e5967b24f8c9aa5bfaab1a82ceb)

> 그래서 kOps 에서는 파드 개수를 제한하나? IP 대역대를 넘기는 POD 를 생성할 수 없을 것이고, 만약 넘긴다면 노드가 위험해지니 클러스터가 망가질수 있을 것 같다. 그냥 이건 개인적인 생각이다.

워커 노드에 생성 가능한 최대 파드 갯수

![](images/2023-03-18-08-45-24.png)
> 그림 출처: [CloudNet@ Blog](https://gasidaseo.notion.site/AWS-EKS-VPC-CNI-1-POD-f89e3e5967b24f8c9aa5bfaab1a82ceb)

## 실습

* 네트워크 기본 정보 확인

```shell
# 노드 IP 확인
❯ aws ec2 describe-instances --query "Reservations[*].Instances[*].{PublicIPAdd:PublicIpAddress,PrivateIPAdd:PrivateIpAddress,InstanceName:Tags[?Key=='Name']|[0].Value,Status:State.Name}" --filters Name=instance-state-name,Values=running --output table | grep ''
---------------------------------------------------------------------------------------------
|                                     DescribeInstances                                     |
+---------------------------------------------+----------------+----------------+-----------+
|                InstanceName                 | PrivateIPAdd   |  PublicIPAdd   |  Status   |
+---------------------------------------------+----------------+----------------+-----------+
|  nodes-ap-northeast-2c.ejpark.link          |  172.30.77.200 |  43.201.25.172 |  running  |
|  master-ap-northeast-2a.masters.ejpark.link |  172.30.47.189 |  3.36.26.76    |  running  |
|  nodes-ap-northeast-2a.ejpark.link          |  172.30.62.109 |  52.78.13.229  |  running  |
+---------------------------------------------+----------------+----------------+-----------+

❯ ssh -i ~/.ssh/id_rsa ubuntu@3.36.26.76 

# CNI 정보 확인
ubuntu@i-0ad86f23f13499914:~$ kubectl describe daemonset aws-node --namespace kube-system | grep Image | cut -d "/" -f 2
amazon-k8s-cni-init:v1.11.4
amazon-k8s-cni:v1.11.4

# 파드 IP 확인
ubuntu@i-0ad86f23f13499914:~$ kubectl get pod -n kube-system -o=custom-columns=NAME:.metadata.name,IP:.status.podIP,STATUS:.status.phase
NAME                                          IP              STATUS
aws-cloud-controller-manager-dzbcm            172.30.47.189   Running
aws-node-b2xrp                                172.30.47.189   Running
aws-node-h5ltq                                172.30.77.200   Running
aws-node-rpvlm                                172.30.62.109   Running
coredns-6897c49dc4-qlrck                      172.30.35.22    Running
coredns-6897c49dc4-snk4b                      172.30.67.252   Running
coredns-autoscaler-5685d4f67b-9kd6c           172.30.32.154   Running
dns-controller-844ddc7657-sw79t               172.30.47.189   Running
ebs-csi-controller-776c4cfdf6-cr5wc           172.30.50.245   Running
ebs-csi-node-55nxx                            172.30.87.105   Running
ebs-csi-node-h4gmp                            172.30.54.154   Running
ebs-csi-node-hv2j2                            172.30.42.74    Running
etcd-manager-events-i-0ad86f23f13499914       172.30.47.189   Running
etcd-manager-main-i-0ad86f23f13499914         172.30.47.189   Running
kops-controller-xlhws                         172.30.47.189   Running
kube-apiserver-i-0ad86f23f13499914            172.30.47.189   Running
kube-controller-manager-i-0ad86f23f13499914   172.30.47.189   Running
kube-proxy-i-01cadf0d8d3c7a565                172.30.77.200   Running
kube-proxy-i-0ad86f23f13499914                172.30.47.189   Running
kube-proxy-i-0f395f78142396d9d                172.30.62.109   Running
kube-scheduler-i-0ad86f23f13499914            172.30.47.189   Running

# 파드 이름 확인
ubuntu@i-0ad86f23f13499914:~$ kubectl get pod -A -o name
pod/aws-cloud-controller-manager-dzbcm
pod/aws-node-b2xrp
pod/aws-node-h5ltq
pod/aws-node-rpvlm
pod/coredns-6897c49dc4-qlrck
pod/coredns-6897c49dc4-snk4b
pod/coredns-autoscaler-5685d4f67b-9kd6c
pod/dns-controller-844ddc7657-sw79t
pod/ebs-csi-controller-776c4cfdf6-cr5wc
pod/ebs-csi-node-55nxx
pod/ebs-csi-node-h4gmp
pod/ebs-csi-node-hv2j2
pod/etcd-manager-events-i-0ad86f23f13499914
pod/etcd-manager-main-i-0ad86f23f13499914
pod/kops-controller-xlhws
pod/kube-apiserver-i-0ad86f23f13499914
pod/kube-controller-manager-i-0ad86f23f13499914
pod/kube-proxy-i-01cadf0d8d3c7a565
pod/kube-proxy-i-0ad86f23f13499914
pod/kube-proxy-i-0f395f78142396d9d
pod/kube-scheduler-i-0ad86f23f13499914

# [master node] aws vpc cni log
❯ ssh -i ~/.ssh/id_rsa ubuntu@api.$KOPS_CLUSTER_NAME ls /var/log/aws-routed-eni
egress-v4-plugin.log
ipamd.log
plugin.log
```

* master node에 SSH 접속 후 확인

```shell
# [master node] SSH 접속
❯ ssh -i ~/.ssh/id_rsa ubuntu@api.$KOPS_CLUSTER_NAME
Welcome to Ubuntu 20.04.5 LTS (GNU/Linux 5.15.0-1031-aws x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Sun Mar 19 00:08:19 UTC 2023

  System load:  0.12              Processes:             165
  Usage of /:   9.3% of 61.84GB   Users logged in:       0
  Memory usage: 29%               IPv4 address for ens5: 172.30.47.189
  Swap usage:   0%                IPv4 address for ens6: 172.30.32.28

(...)

# 툴 설치
ubuntu@i-0ad86f23f13499914:~$ sudo apt install -y tree jq net-tools

# CNI 정보 확인
ubuntu@i-0ad86f23f13499914:~$ ls /var/log/aws-routed-eni
egress-v4-plugin.log  ipamd.log  plugin.log

ubuntu@i-0ad86f23f13499914:~$ cat /var/log/aws-routed-eni/plugin.log | jq
{
  "level": "info",
  "ts": "2023-03-19T00:01:22.223Z",
  "caller": "routed-eni-cni-plugin/cni.go:119",
  "msg": "Constructed new logger instance"
}

(...)

ubuntu@i-0ad86f23f13499914:~$ cat /var/log/aws-routed-eni/ipamd.log | jq | head
{
  "level": "info",
  "ts": "2023-03-19T00:01:15.232Z",
  "caller": "logger/logger.go:52",
  "msg": "Constructed new logger instance"
}

# 네트워크 정보 확인 : eniY는 pod network 네임스페이스와 veth pair
ubuntu@i-0ad86f23f13499914:~$ ip -br -c addr
lo               UNKNOWN        127.0.0.1/8 ::1/128
ens5             UP             172.30.47.189/19 fe80::5e:13ff:fe29:8814/64
enid914a74f540@if3 UP             fe80::acb7:ebff:fecc:b1cc/64
enieb5ea8b4376@if3 UP             fe80::9048:2ff:fe96:2c6b/64
ens6             UP             172.30.32.28/19 fe80::3a:aaff:fec6:7356/64

ubuntu@i-0ad86f23f13499914:~$ ip -c addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: ens5: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc mq state UP group default qlen 1000
    link/ether 02:5e:13:29:88:14 brd ff:ff:ff:ff:ff:ff
    altname enp0s5
    inet 172.30.47.189/19 brd 172.30.63.255 scope global dynamic ens5
       valid_lft 2893sec preferred_lft 2893sec
    inet6 fe80::5e:13ff:fe29:8814/64 scope link
       valid_lft forever preferred_lft forever
3: enid914a74f540@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc noqueue state UP group default
    link/ether ae:b7:eb:cc:b1:cc brd ff:ff:ff:ff:ff:ff link-netns cni-bbb26389-6ac1-8f3e-2165-2b21009b3909
    inet6 fe80::acb7:ebff:fecc:b1cc/64 scope link
       valid_lft forever preferred_lft forever
4: enieb5ea8b4376@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc noqueue state UP group default
    link/ether 92:48:02:96:2c:6b brd ff:ff:ff:ff:ff:ff link-netns cni-1034e837-1355-b2cc-6918-a93c6d34563c
    inet6 fe80::9048:2ff:fe96:2c6b/64 scope link
       valid_lft forever preferred_lft forever
5: ens6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc mq state UP group default qlen 1000
    link/ether 02:3a:aa:c6:73:56 brd ff:ff:ff:ff:ff:ff
    altname enp0s6
    inet 172.30.32.28/19 brd 172.30.63.255 scope global ens6
       valid_lft forever preferred_lft forever
    inet6 fe80::3a:aaff:fec6:7356/64 scope link
       valid_lft forever preferred_lft forever

ubuntu@i-0ad86f23f13499914:~$ ip -c route
default via 172.30.32.1 dev ens5 proto dhcp src 172.30.47.189 metric 100
172.30.32.0/19 dev ens5 proto kernel scope link src 172.30.47.189
172.30.32.1 dev ens5 proto dhcp scope link src 172.30.47.189 metric 100
172.30.50.245 dev enieb5ea8b4376 scope link
172.30.54.154 dev enid914a74f540 scope link

ubuntu@i-0ad86f23f13499914:~$ sudo iptables -t nat -S
-P PREROUTING ACCEPT
-P INPUT ACCEPT
-P OUTPUT ACCEPT
-P POSTROUTING ACCEPT
-N AWS-CONNMARK-CHAIN-0
-N AWS-CONNMARK-CHAIN-1
-N AWS-SNAT-CHAIN-0
-N AWS-SNAT-CHAIN-1
-N KUBE-KUBELET-CANARY
-N KUBE-MARK-DROP
-N KUBE-MARK-MASQ
-N KUBE-NODEPORTS
-N KUBE-POSTROUTING
-N KUBE-PROXY-CANARY
-N KUBE-SEP-2ZRLULZUW5ZRJPDH
-N KUBE-SEP-7X6AO62GIOXV3FVU
-N KUBE-SEP-E5VE4QQSILFWIGM4
-N KUBE-SEP-F34FWTZSD5CRXDSN
-N KUBE-SEP-GQ5ILYDZNB4UO27Z
-N KUBE-SEP-JKPKL7GFGRUS3R5T
-N KUBE-SEP-W7Z2VQWXN5OBAHCZ
-N KUBE-SERVICES
-N KUBE-SVC-ERIFXISQEP7F7OF4
-N KUBE-SVC-JD5MR3NA4I4DYORP
-N KUBE-SVC-NPX46M4PTMTKRN6Y
-N KUBE-SVC-TCOU7JCQXEZGVUNU
-A PREROUTING -m comment --comment "kubernetes service portals" -j KUBE-SERVICES
-A PREROUTING -i eni+ -m comment --comment "AWS, outbound connections" -m state --state NEW -j AWS-CONNMARK-CHAIN-0
-A PREROUTING -m comment --comment "AWS, CONNMARK" -j CONNMARK --restore-mark --nfmask 0x80 --ctmask 0x80
-A OUTPUT -m comment --comment "kubernetes service portals" -j KUBE-SERVICES
-A POSTROUTING -m comment --comment "kubernetes postrouting rules" -j KUBE-POSTROUTING
-A POSTROUTING -m comment --comment "AWS SNAT CHAIN" -j AWS-SNAT-CHAIN-0
-A AWS-CONNMARK-CHAIN-0 ! -d 172.30.0.0/16 -m comment --comment "AWS CONNMARK CHAIN, VPC CIDR" -j AWS-CONNMARK-CHAIN-1
-A AWS-CONNMARK-CHAIN-1 -m comment --comment "AWS, CONNMARK" -j CONNMARK --set-xmark 0x80/0x80
-A AWS-SNAT-CHAIN-0 ! -d 172.30.0.0/16 -m comment --comment "AWS SNAT CHAIN" -j AWS-SNAT-CHAIN-1
-A AWS-SNAT-CHAIN-1 ! -o vlan+ -m comment --comment "AWS, SNAT" -m addrtype ! --dst-type LOCAL -j SNAT --to-source 172.30.47.189 --random-fully
-A KUBE-MARK-DROP -j MARK --set-xmark 0x8000/0x8000
-A KUBE-MARK-MASQ -j MARK --set-xmark 0x4000/0x4000
-A KUBE-POSTROUTING -m mark ! --mark 0x4000/0x4000 -j RETURN
-A KUBE-POSTROUTING -j MARK --set-xmark 0x4000/0x0
-A KUBE-POSTROUTING -m comment --comment "kubernetes service traffic requiring SNAT" -j MASQUERADE --random-fully
-A KUBE-SEP-2ZRLULZUW5ZRJPDH -s 172.30.67.252/32 -m comment --comment "kube-system/kube-dns:dns" -j KUBE-MARK-MASQ
-A KUBE-SEP-2ZRLULZUW5ZRJPDH -p udp -m comment --comment "kube-system/kube-dns:dns" -m udp -j DNAT --to-destination 172.30.67.252:53
-A KUBE-SEP-7X6AO62GIOXV3FVU -s 172.30.67.252/32 -m comment --comment "kube-system/kube-dns:metrics" -j KUBE-MARK-MASQ
-A KUBE-SEP-7X6AO62GIOXV3FVU -p tcp -m comment --comment "kube-system/kube-dns:metrics" -m tcp -j DNAT --to-destination 172.30.67.252:9153
-A KUBE-SEP-E5VE4QQSILFWIGM4 -s 172.30.35.22/32 -m comment --comment "kube-system/kube-dns:metrics" -j KUBE-MARK-MASQ
-A KUBE-SEP-E5VE4QQSILFWIGM4 -p tcp -m comment --comment "kube-system/kube-dns:metrics" -m tcp -j DNAT --to-destination 172.30.35.22:9153
-A KUBE-SEP-F34FWTZSD5CRXDSN -s 172.30.67.252/32 -m comment --comment "kube-system/kube-dns:dns-tcp" -j KUBE-MARK-MASQ
-A KUBE-SEP-F34FWTZSD5CRXDSN -p tcp -m comment --comment "kube-system/kube-dns:dns-tcp" -m tcp -j DNAT --to-destination 172.30.67.252:53
-A KUBE-SEP-GQ5ILYDZNB4UO27Z -s 172.30.47.189/32 -m comment --comment "default/kubernetes:https" -j KUBE-MARK-MASQ
-A KUBE-SEP-GQ5ILYDZNB4UO27Z -p tcp -m comment --comment "default/kubernetes:https" -m tcp -j DNAT --to-destination 172.30.47.189:443
-A KUBE-SEP-JKPKL7GFGRUS3R5T -s 172.30.35.22/32 -m comment --comment "kube-system/kube-dns:dns-tcp" -j KUBE-MARK-MASQ
-A KUBE-SEP-JKPKL7GFGRUS3R5T -p tcp -m comment --comment "kube-system/kube-dns:dns-tcp" -m tcp -j DNAT --to-destination 172.30.35.22:53
-A KUBE-SEP-W7Z2VQWXN5OBAHCZ -s 172.30.35.22/32 -m comment --comment "kube-system/kube-dns:dns" -j KUBE-MARK-MASQ
-A KUBE-SEP-W7Z2VQWXN5OBAHCZ -p udp -m comment --comment "kube-system/kube-dns:dns" -m udp -j DNAT --to-destination 172.30.35.22:53
-A KUBE-SERVICES -d 100.64.0.1/32 -p tcp -m comment --comment "default/kubernetes:https cluster IP" -m tcp --dport 443 -j KUBE-SVC-NPX46M4PTMTKRN6Y
-A KUBE-SERVICES -d 100.64.0.10/32 -p tcp -m comment --comment "kube-system/kube-dns:dns-tcp cluster IP" -m tcp --dport 53 -j KUBE-SVC-ERIFXISQEP7F7OF4
-A KUBE-SERVICES -d 100.64.0.10/32 -p tcp -m comment --comment "kube-system/kube-dns:metrics cluster IP" -m tcp --dport 9153 -j KUBE-SVC-JD5MR3NA4I4DYORP
-A KUBE-SERVICES -d 100.64.0.10/32 -p udp -m comment --comment "kube-system/kube-dns:dns cluster IP" -m udp --dport 53 -j KUBE-SVC-TCOU7JCQXEZGVUNU
-A KUBE-SERVICES -m comment --comment "kubernetes service nodeports; NOTE: this must be the last rule in this chain" -m addrtype --dst-type LOCAL -j KUBE-NODEPORTS
-A KUBE-SVC-ERIFXISQEP7F7OF4 -m comment --comment "kube-system/kube-dns:dns-tcp -> 172.30.35.22:53" -m statistic --mode random --probability 0.50000000000 -j KUBE-SEP-JKPKL7GFGRUS3R5T
-A KUBE-SVC-ERIFXISQEP7F7OF4 -m comment --comment "kube-system/kube-dns:dns-tcp -> 172.30.67.252:53" -j KUBE-SEP-F34FWTZSD5CRXDSN
-A KUBE-SVC-JD5MR3NA4I4DYORP -m comment --comment "kube-system/kube-dns:metrics -> 172.30.35.22:9153" -m statistic --mode random --probability 0.50000000000 -j KUBE-SEP-E5VE4QQSILFWIGM4
-A KUBE-SVC-JD5MR3NA4I4DYORP -m comment --comment "kube-system/kube-dns:metrics -> 172.30.67.252:9153" -j KUBE-SEP-7X6AO62GIOXV3FVU
-A KUBE-SVC-NPX46M4PTMTKRN6Y -m comment --comment "default/kubernetes:https -> 172.30.47.189:443" -j KUBE-SEP-GQ5ILYDZNB4UO27Z
-A KUBE-SVC-TCOU7JCQXEZGVUNU -m comment --comment "kube-system/kube-dns:dns -> 172.30.35.22:53" -m statistic --mode random --probability 0.50000000000 -j KUBE-SEP-W7Z2VQWXN5OBAHCZ
-A KUBE-SVC-TCOU7JCQXEZGVUNU -m comment --comment "kube-system/kube-dns:dns -> 172.30.67.252:53" -j KUBE-SEP-2ZRLULZUW5ZRJPDH


ubuntu@i-0ad86f23f13499914:~$ sudo iptables -t nat -L -n -v
Chain PREROUTING (policy ACCEPT 9 packets, 480 bytes)
 pkts bytes target     prot opt in     out     source               destination
   43  2512 KUBE-SERVICES  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service portals */
   12   720 AWS-CONNMARK-CHAIN-0  all  --  eni+   *       0.0.0.0/0            0.0.0.0/0            /* AWS, outbound connections */ state NEW
   33  1912 CONNMARK   all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* AWS, CONNMARK */ CONNMARK restore mask 0x80

Chain INPUT (policy ACCEPT 9 packets, 480 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain OUTPUT (policy ACCEPT 1325 packets, 91952 bytes)
 pkts bytes target     prot opt in     out     source               destination
 1935  136K KUBE-SERVICES  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service portals */

Chain POSTROUTING (policy ACCEPT 1015 packets, 73320 bytes)
 pkts bytes target     prot opt in     out     source               destination
 2346  164K KUBE-POSTROUTING  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes postrouting rules */
 1657  115K AWS-SNAT-CHAIN-0  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* AWS SNAT CHAIN */

Chain AWS-CONNMARK-CHAIN-0 (1 references)
 pkts bytes target     prot opt in     out     source               destination
   12   720 AWS-CONNMARK-CHAIN-1  all  --  *      *       0.0.0.0/0           !172.30.0.0/16        /* AWS CONNMARK CHAIN, VPC CIDR */

Chain AWS-CONNMARK-CHAIN-1 (1 references)
 pkts bytes target     prot opt in     out     source               destination
   12   720 CONNMARK   all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* AWS, CONNMARK */ CONNMARK or 0x80

Chain AWS-SNAT-CHAIN-0 (1 references)
 pkts bytes target     prot opt in     out     source               destination
  951 60456 AWS-SNAT-CHAIN-1  all  --  *      *       0.0.0.0/0           !172.30.0.0/16        /* AWS SNAT CHAIN */

Chain AWS-SNAT-CHAIN-1 (1 references)
 pkts bytes target     prot opt in     out     source               destination
  469 28172 SNAT       all  --  *      !vlan+  0.0.0.0/0            0.0.0.0/0            /* AWS, SNAT */ ADDRTYPE match dst-type !LOCAL to:172.30.47.189 random-fully

Chain KUBE-KUBELET-CANARY (0 references)
 pkts bytes target     prot opt in     out     source               destination

Chain KUBE-MARK-DROP (0 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 MARK       all  --  *      *       0.0.0.0/0            0.0.0.0/0            MARK or 0x8000

Chain KUBE-MARK-MASQ (7 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 MARK       all  --  *      *       0.0.0.0/0            0.0.0.0/0            MARK or 0x4000

Chain KUBE-NODEPORTS (1 references)
 pkts bytes target     prot opt in     out     source               destination

Chain KUBE-POSTROUTING (1 references)
 pkts bytes target     prot opt in     out     source               destination
 1325 91952 RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0            mark match ! 0x4000/0x4000
    0     0 MARK       all  --  *      *       0.0.0.0/0            0.0.0.0/0            MARK xor 0x4000
    0     0 MASQUERADE  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service traffic requiring SNAT */ random-fully

Chain KUBE-PROXY-CANARY (0 references)
 pkts bytes target     prot opt in     out     source               destination

Chain KUBE-SEP-2ZRLULZUW5ZRJPDH (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  all  --  *      *       172.30.67.252        0.0.0.0/0            /* kube-system/kube-dns:dns */
    0     0 DNAT       udp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:dns */ udp to:172.30.67.252:53

Chain KUBE-SEP-7X6AO62GIOXV3FVU (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  all  --  *      *       172.30.67.252        0.0.0.0/0            /* kube-system/kube-dns:metrics */
    0     0 DNAT       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:metrics */ tcp to:172.30.67.252:9153

Chain KUBE-SEP-E5VE4QQSILFWIGM4 (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  all  --  *      *       172.30.35.22         0.0.0.0/0            /* kube-system/kube-dns:metrics */
    0     0 DNAT       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:metrics */ tcp to:172.30.35.22:9153

Chain KUBE-SEP-F34FWTZSD5CRXDSN (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  all  --  *      *       172.30.67.252        0.0.0.0/0            /* kube-system/kube-dns:dns-tcp */
    0     0 DNAT       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:dns-tcp */ tcp to:172.30.67.252:53

Chain KUBE-SEP-GQ5ILYDZNB4UO27Z (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  all  --  *      *       172.30.47.189        0.0.0.0/0            /* default/kubernetes:https */
    0     0 DNAT       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/kubernetes:https */ tcp to:172.30.47.189:443

Chain KUBE-SEP-JKPKL7GFGRUS3R5T (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  all  --  *      *       172.30.35.22         0.0.0.0/0            /* kube-system/kube-dns:dns-tcp */
    0     0 DNAT       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:dns-tcp */ tcp to:172.30.35.22:53

Chain KUBE-SEP-W7Z2VQWXN5OBAHCZ (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  all  --  *      *       172.30.35.22         0.0.0.0/0            /* kube-system/kube-dns:dns */
    0     0 DNAT       udp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:dns */ udp to:172.30.35.22:53

Chain KUBE-SERVICES (2 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-SVC-NPX46M4PTMTKRN6Y  tcp  --  *      *       0.0.0.0/0            100.64.0.1           /* default/kubernetes:https cluster IP */ tcp dpt:443
    0     0 KUBE-SVC-ERIFXISQEP7F7OF4  tcp  --  *      *       0.0.0.0/0            100.64.0.10          /* kube-system/kube-dns:dns-tcp cluster IP */ tcp dpt:53
    0     0 KUBE-SVC-JD5MR3NA4I4DYORP  tcp  --  *      *       0.0.0.0/0            100.64.0.10          /* kube-system/kube-dns:metrics cluster IP */ tcp dpt:9153
    0     0 KUBE-SVC-TCOU7JCQXEZGVUNU  udp  --  *      *       0.0.0.0/0            100.64.0.10          /* kube-system/kube-dns:dns cluster IP */ udp dpt:53
  603 37993 KUBE-NODEPORTS  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service nodeports; NOTE: this must be the last rule in this chain */ ADDRTYPE match dst-type LOCAL

Chain KUBE-SVC-ERIFXISQEP7F7OF4 (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-SEP-JKPKL7GFGRUS3R5T  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:dns-tcp -> 172.30.35.22:53 */ statistic mode random probability 0.50000000000
    0     0 KUBE-SEP-F34FWTZSD5CRXDSN  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:dns-tcp -> 172.30.67.252:53 */

Chain KUBE-SVC-JD5MR3NA4I4DYORP (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-SEP-E5VE4QQSILFWIGM4  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:metrics -> 172.30.35.22:9153 */ statistic mode random probability 0.50000000000
    0     0 KUBE-SEP-7X6AO62GIOXV3FVU  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:metrics -> 172.30.67.252:9153 */

Chain KUBE-SVC-NPX46M4PTMTKRN6Y (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-SEP-GQ5ILYDZNB4UO27Z  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/kubernetes:https -> 172.30.47.189:443 */

Chain KUBE-SVC-TCOU7JCQXEZGVUNU (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-SEP-W7Z2VQWXN5OBAHCZ  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:dns -> 172.30.35.22:53 */ statistic mode random probability 0.50000000000
    0     0 KUBE-SEP-2ZRLULZUW5ZRJPDH  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:dns -> 172.30.67.252:53 */
```

* 워커 노드에 SSH 접속 후 확인 : 워커 노드의 public ip 로 SSH 접속

```shell
# 워커 노드 Public IP 확인
❯ aws ec2 describe-instances --query "Reservations[*].Instances[*].{PublicIPAdd:PublicIpAddress,InstanceName:Tags[?Key=='Name']|[0].Value}" --filters Name=instance-state-name,Values=running --output table | grep ''
-----------------------------------------------------------------
|                       DescribeInstances                       |
+---------------------------------------------+-----------------+
|                InstanceName                 |   PublicIPAdd   |
+---------------------------------------------+-----------------+
|  nodes-ap-northeast-2c.ejpark.link          |  43.201.25.172  |
|  master-ap-northeast-2a.masters.ejpark.link |  3.36.26.76     |
|  nodes-ap-northeast-2a.ejpark.link          |  52.78.13.229   |
+---------------------------------------------+-----------------+

# 워커 노드 Public IP 변수 지정
❯ export W1PIP=43.201.25.172 
❯ export W2PIP=52.78.13.229

# 워커 노드 SSH 접속
❯ ssh -i ~/.ssh/id_rsa ubuntu@$W1PIP
Welcome to Ubuntu 20.04.5 LTS (GNU/Linux 5.15.0-1031-aws x86_64)
(...)

❯ ssh -i ~/.ssh/id_rsa ubuntu@$W2PIP
Welcome to Ubuntu 20.04.5 LTS (GNU/Linux 5.15.0-1031-aws x86_64)
(...)

# [워커 노드1~2] SSH 접속 : 접속 후 아래 툴 설치 등 정보 각각 확인
❯ ssh -i ~/.ssh/id_rsa ubuntu@$W1PIP
Welcome to Ubuntu 20.04.5 LTS (GNU/Linux 5.15.0-1031-aws x86_64)

# 툴 설치
ubuntu@i-01cadf0d8d3c7a565:~$ sudo apt install -y tree jq net-tools
(...)

# CNI 정보 확인
ubuntu@i-01cadf0d8d3c7a565:~$ ls /var/log/aws-routed-eni
egress-v4-plugin.log  ipamd.log  plugin.log

ubuntu@i-01cadf0d8d3c7a565:~$ cat /var/log/aws-routed-eni/plugin.log | jq | head
{
  "level": "info",
  "ts": "2023-03-19T00:02:13.315Z",
  "caller": "routed-eni-cni-plugin/cni.go:119",
  "msg": "Constructed new logger instance"
}
{
  "level": "info",
  "ts": "2023-03-19T00:02:13.315Z",
  "caller": "routed-eni-cni-plugin/cni.go:128",

ubuntu@i-01cadf0d8d3c7a565:~$ cat /var/log/aws-routed-eni/ipamd.log | jq | head
{
  "level": "info",
  "ts": "2023-03-19T00:02:07.393Z",
  "caller": "logger/logger.go:52",
  "msg": "Constructed new logger instance"
}
{
  "level": "info",
  "ts": "2023-03-19T00:02:07.393Z",
  "caller": "eniconfig/eniconfig.go:61",

# 네트워크 정보 확인
ubuntu@i-01cadf0d8d3c7a565:~$ ip -br -c addr
lo               UNKNOWN        127.0.0.1/8 ::1/128
ens5             UP             172.30.77.200/19 fe80::8da:d8ff:fe5d:f35a/64
enie241f3eec46@if3 UP             fe80::436:beff:fe8f:ef38/64
eni037a5c81799@if3 UP             fe80::f4a6:44ff:fe15:9414/64
ens6             UP             172.30.65.84/19 fe80::88f:e8ff:fe7e:748a/64

ubuntu@i-01cadf0d8d3c7a565:~$ ip -c addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: ens5: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc mq state UP group default qlen 1000
    link/ether 0a:da:d8:5d:f3:5a brd ff:ff:ff:ff:ff:ff
    altname enp0s5
    inet 172.30.77.200/19 brd 172.30.95.255 scope global dynamic ens5
       valid_lft 2603sec preferred_lft 2603sec
    inet6 fe80::8da:d8ff:fe5d:f35a/64 scope link
       valid_lft forever preferred_lft forever
3: enie241f3eec46@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc noqueue state UP group default
    link/ether 06:36:be:8f:ef:38 brd ff:ff:ff:ff:ff:ff link-netns cni-7aadb553-9328-7eac-6391-fd6b48ca0118
    inet6 fe80::436:beff:fe8f:ef38/64 scope link
       valid_lft forever preferred_lft forever
4: eni037a5c81799@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc noqueue state UP group default
    link/ether f6:a6:44:15:94:14 brd ff:ff:ff:ff:ff:ff link-netns cni-9338ac3b-7cd4-0e18-3274-fe15d70f888f
    inet6 fe80::f4a6:44ff:fe15:9414/64 scope link
       valid_lft forever preferred_lft forever
5: ens6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc mq state UP group default qlen 1000
    link/ether 0a:8f:e8:7e:74:8a brd ff:ff:ff:ff:ff:ff
    altname enp0s6
    inet 172.30.65.84/19 brd 172.30.95.255 scope global ens6
       valid_lft forever preferred_lft forever
    inet6 fe80::88f:e8ff:fe7e:748a/64 scope link
       valid_lft forever preferred_lft forever
    
ubuntu@i-01cadf0d8d3c7a565:~$ ip -c route
default via 172.30.64.1 dev ens5 proto dhcp src 172.30.77.200 metric 100
172.30.64.0/19 dev ens5 proto kernel scope link src 172.30.77.200
172.30.64.1 dev ens5 proto dhcp scope link src 172.30.77.200 metric 100
172.30.67.252 dev eni037a5c81799 scope link
172.30.87.105 dev enie241f3eec46 scope link

ubuntu@i-01cadf0d8d3c7a565:~$ sudo iptables -t nat -S
-P PREROUTING ACCEPT
-P INPUT ACCEPT
-P OUTPUT ACCEPT
-P POSTROUTING ACCEPT
-N AWS-CONNMARK-CHAIN-0
-N AWS-CONNMARK-CHAIN-1
-N AWS-SNAT-CHAIN-0
-N AWS-SNAT-CHAIN-1
-N KUBE-KUBELET-CANARY
-N KUBE-MARK-DROP
-N KUBE-MARK-MASQ
-N KUBE-NODEPORTS
-N KUBE-POSTROUTING
-N KUBE-PROXY-CANARY
-N KUBE-SEP-2ZRLULZUW5ZRJPDH
-N KUBE-SEP-7X6AO62GIOXV3FVU
-N KUBE-SEP-E5VE4QQSILFWIGM4
-N KUBE-SEP-F34FWTZSD5CRXDSN
-N KUBE-SEP-GQ5ILYDZNB4UO27Z
-N KUBE-SEP-JKPKL7GFGRUS3R5T
-N KUBE-SEP-W7Z2VQWXN5OBAHCZ
-N KUBE-SERVICES
-N KUBE-SVC-ERIFXISQEP7F7OF4
-N KUBE-SVC-JD5MR3NA4I4DYORP
-N KUBE-SVC-NPX46M4PTMTKRN6Y
-N KUBE-SVC-TCOU7JCQXEZGVUNU
-A PREROUTING -m comment --comment "kubernetes service portals" -j KUBE-SERVICES
-A PREROUTING -i eni+ -m comment --comment "AWS, outbound connections" -m state --state NEW -j AWS-CONNMARK-CHAIN-0
-A PREROUTING -m comment --comment "AWS, CONNMARK" -j CONNMARK --restore-mark --nfmask 0x80 --ctmask 0x80
-A OUTPUT -m comment --comment "kubernetes service portals" -j KUBE-SERVICES
-A POSTROUTING -m comment --comment "kubernetes postrouting rules" -j KUBE-POSTROUTING
-A POSTROUTING -m comment --comment "AWS SNAT CHAIN" -j AWS-SNAT-CHAIN-0
-A AWS-CONNMARK-CHAIN-0 ! -d 172.30.0.0/16 -m comment --comment "AWS CONNMARK CHAIN, VPC CIDR" -j AWS-CONNMARK-CHAIN-1
-A AWS-CONNMARK-CHAIN-1 -m comment --comment "AWS, CONNMARK" -j CONNMARK --set-xmark 0x80/0x80
-A AWS-SNAT-CHAIN-0 ! -d 172.30.0.0/16 -m comment --comment "AWS SNAT CHAIN" -j AWS-SNAT-CHAIN-1
-A AWS-SNAT-CHAIN-1 ! -o vlan+ -m comment --comment "AWS, SNAT" -m addrtype ! --dst-type LOCAL -j SNAT --to-source 172.30.77.200 --random-fully
-A KUBE-MARK-DROP -j MARK --set-xmark 0x8000/0x8000
-A KUBE-MARK-MASQ -j MARK --set-xmark 0x4000/0x4000
-A KUBE-POSTROUTING -m mark ! --mark 0x4000/0x4000 -j RETURN
-A KUBE-POSTROUTING -j MARK --set-xmark 0x4000/0x0
-A KUBE-POSTROUTING -m comment --comment "kubernetes service traffic requiring SNAT" -j MASQUERADE --random-fully
-A KUBE-SEP-2ZRLULZUW5ZRJPDH -s 172.30.67.252/32 -m comment --comment "kube-system/kube-dns:dns" -j KUBE-MARK-MASQ
-A KUBE-SEP-2ZRLULZUW5ZRJPDH -p udp -m comment --comment "kube-system/kube-dns:dns" -m udp -j DNAT --to-destination 172.30.67.252:53
-A KUBE-SEP-7X6AO62GIOXV3FVU -s 172.30.67.252/32 -m comment --comment "kube-system/kube-dns:metrics" -j KUBE-MARK-MASQ
-A KUBE-SEP-7X6AO62GIOXV3FVU -p tcp -m comment --comment "kube-system/kube-dns:metrics" -m tcp -j DNAT --to-destination 172.30.67.252:9153
-A KUBE-SEP-E5VE4QQSILFWIGM4 -s 172.30.35.22/32 -m comment --comment "kube-system/kube-dns:metrics" -j KUBE-MARK-MASQ
-A KUBE-SEP-E5VE4QQSILFWIGM4 -p tcp -m comment --comment "kube-system/kube-dns:metrics" -m tcp -j DNAT --to-destination 172.30.35.22:9153
-A KUBE-SEP-F34FWTZSD5CRXDSN -s 172.30.67.252/32 -m comment --comment "kube-system/kube-dns:dns-tcp" -j KUBE-MARK-MASQ
-A KUBE-SEP-F34FWTZSD5CRXDSN -p tcp -m comment --comment "kube-system/kube-dns:dns-tcp" -m tcp -j DNAT --to-destination 172.30.67.252:53
-A KUBE-SEP-GQ5ILYDZNB4UO27Z -s 172.30.47.189/32 -m comment --comment "default/kubernetes:https" -j KUBE-MARK-MASQ
-A KUBE-SEP-GQ5ILYDZNB4UO27Z -p tcp -m comment --comment "default/kubernetes:https" -m tcp -j DNAT --to-destination 172.30.47.189:443
-A KUBE-SEP-JKPKL7GFGRUS3R5T -s 172.30.35.22/32 -m comment --comment "kube-system/kube-dns:dns-tcp" -j KUBE-MARK-MASQ
-A KUBE-SEP-JKPKL7GFGRUS3R5T -p tcp -m comment --comment "kube-system/kube-dns:dns-tcp" -m tcp -j DNAT --to-destination 172.30.35.22:53
-A KUBE-SEP-W7Z2VQWXN5OBAHCZ -s 172.30.35.22/32 -m comment --comment "kube-system/kube-dns:dns" -j KUBE-MARK-MASQ
-A KUBE-SEP-W7Z2VQWXN5OBAHCZ -p udp -m comment --comment "kube-system/kube-dns:dns" -m udp -j DNAT --to-destination 172.30.35.22:53
-A KUBE-SERVICES -d 100.64.0.1/32 -p tcp -m comment --comment "default/kubernetes:https cluster IP" -m tcp --dport 443 -j KUBE-SVC-NPX46M4PTMTKRN6Y
-A KUBE-SERVICES -d 100.64.0.10/32 -p udp -m comment --comment "kube-system/kube-dns:dns cluster IP" -m udp --dport 53 -j KUBE-SVC-TCOU7JCQXEZGVUNU
-A KUBE-SERVICES -d 100.64.0.10/32 -p tcp -m comment --comment "kube-system/kube-dns:dns-tcp cluster IP" -m tcp --dport 53 -j KUBE-SVC-ERIFXISQEP7F7OF4
-A KUBE-SERVICES -d 100.64.0.10/32 -p tcp -m comment --comment "kube-system/kube-dns:metrics cluster IP" -m tcp --dport 9153 -j KUBE-SVC-JD5MR3NA4I4DYORP
-A KUBE-SERVICES -m comment --comment "kubernetes service nodeports; NOTE: this must be the last rule in this chain" -m addrtype --dst-type LOCAL -j KUBE-NODEPORTS
-A KUBE-SVC-ERIFXISQEP7F7OF4 -m comment --comment "kube-system/kube-dns:dns-tcp -> 172.30.35.22:53" -m statistic --mode random --probability 0.50000000000 -j KUBE-SEP-JKPKL7GFGRUS3R5T
-A KUBE-SVC-ERIFXISQEP7F7OF4 -m comment --comment "kube-system/kube-dns:dns-tcp -> 172.30.67.252:53" -j KUBE-SEP-F34FWTZSD5CRXDSN
-A KUBE-SVC-JD5MR3NA4I4DYORP -m comment --comment "kube-system/kube-dns:metrics -> 172.30.35.22:9153" -m statistic --mode random --probability 0.50000000000 -j KUBE-SEP-E5VE4QQSILFWIGM4
-A KUBE-SVC-JD5MR3NA4I4DYORP -m comment --comment "kube-system/kube-dns:metrics -> 172.30.67.252:9153" -j KUBE-SEP-7X6AO62GIOXV3FVU
-A KUBE-SVC-NPX46M4PTMTKRN6Y -m comment --comment "default/kubernetes:https -> 172.30.47.189:443" -j KUBE-SEP-GQ5ILYDZNB4UO27Z
-A KUBE-SVC-TCOU7JCQXEZGVUNU -m comment --comment "kube-system/kube-dns:dns -> 172.30.35.22:53" -m statistic --mode random --probability 0.50000000000 -j KUBE-SEP-W7Z2VQWXN5OBAHCZ
-A KUBE-SVC-TCOU7JCQXEZGVUNU -m comment --comment "kube-system/kube-dns:dns -> 172.30.67.252:53" -j KUBE-SEP-2ZRLULZUW5ZRJPDH

ubuntu@i-01cadf0d8d3c7a565:~$ sudo iptables -t nat -L -n -v
Chain PREROUTING (policy ACCEPT 6 packets, 316 bytes)
 pkts bytes target     prot opt in     out     source               destination
   13   772 KUBE-SERVICES  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service portals */
    5   336 AWS-CONNMARK-CHAIN-0  all  --  eni+   *       0.0.0.0/0            0.0.0.0/0            /* AWS, outbound connections */ state NEW
   11   652 CONNMARK   all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* AWS, CONNMARK */ CONNMARK restore mask 0x80

Chain INPUT (policy ACCEPT 6 packets, 316 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain OUTPUT (policy ACCEPT 664 packets, 40742 bytes)
 pkts bytes target     prot opt in     out     source               destination
  855 54388 KUBE-SERVICES  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service portals */

Chain POSTROUTING (policy ACCEPT 420 packets, 26054 bytes)
 pkts bytes target     prot opt in     out     source               destination
  976 64008 KUBE-POSTROUTING  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes postrouting rules */
  817 51328 AWS-SNAT-CHAIN-0  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* AWS SNAT CHAIN */

Chain AWS-CONNMARK-CHAIN-0 (1 references)
 pkts bytes target     prot opt in     out     source               destination
    4   240 AWS-CONNMARK-CHAIN-1  all  --  *      *       0.0.0.0/0           !172.30.0.0/16        /* AWS CONNMARK CHAIN, VPC CIDR */

Chain AWS-CONNMARK-CHAIN-1 (1 references)
 pkts bytes target     prot opt in     out     source               destination
    4   240 CONNMARK   all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* AWS, CONNMARK */ CONNMARK or 0x80

Chain AWS-SNAT-CHAIN-0 (1 references)
 pkts bytes target     prot opt in     out     source               destination
  555 34699 AWS-SNAT-CHAIN-1  all  --  *      *       0.0.0.0/0           !172.30.0.0/16        /* AWS SNAT CHAIN */

Chain AWS-SNAT-CHAIN-1 (1 references)
 pkts bytes target     prot opt in     out     source               destination
  350 21048 SNAT       all  --  *      !vlan+  0.0.0.0/0            0.0.0.0/0            /* AWS, SNAT */ ADDRTYPE match dst-type !LOCAL to:172.30.77.200 random-fully

Chain KUBE-KUBELET-CANARY (0 references)
 pkts bytes target     prot opt in     out     source               destination

Chain KUBE-MARK-DROP (0 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 MARK       all  --  *      *       0.0.0.0/0            0.0.0.0/0            MARK or 0x8000

Chain KUBE-MARK-MASQ (7 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 MARK       all  --  *      *       0.0.0.0/0            0.0.0.0/0            MARK or 0x4000

Chain KUBE-NODEPORTS (1 references)
 pkts bytes target     prot opt in     out     source               destination

Chain KUBE-POSTROUTING (1 references)
 pkts bytes target     prot opt in     out     source               destination
  664 40742 RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0            mark match ! 0x4000/0x4000
    0     0 MARK       all  --  *      *       0.0.0.0/0            0.0.0.0/0            MARK xor 0x4000
    0     0 MASQUERADE  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service traffic requiring SNAT */ random-fully

Chain KUBE-PROXY-CANARY (0 references)
 pkts bytes target     prot opt in     out     source               destination

Chain KUBE-SEP-2ZRLULZUW5ZRJPDH (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  all  --  *      *       172.30.67.252        0.0.0.0/0            /* kube-system/kube-dns:dns */
    0     0 DNAT       udp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:dns */ udp to:172.30.67.252:53

Chain KUBE-SEP-7X6AO62GIOXV3FVU (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  all  --  *      *       172.30.67.252        0.0.0.0/0            /* kube-system/kube-dns:metrics */
    0     0 DNAT       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:metrics */ tcp to:172.30.67.252:9153

Chain KUBE-SEP-E5VE4QQSILFWIGM4 (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  all  --  *      *       172.30.35.22         0.0.0.0/0            /* kube-system/kube-dns:metrics */
    0     0 DNAT       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:metrics */ tcp to:172.30.35.22:9153

Chain KUBE-SEP-F34FWTZSD5CRXDSN (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  all  --  *      *       172.30.67.252        0.0.0.0/0            /* kube-system/kube-dns:dns-tcp */
    0     0 DNAT       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:dns-tcp */ tcp to:172.30.67.252:53

Chain KUBE-SEP-GQ5ILYDZNB4UO27Z (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  all  --  *      *       172.30.47.189        0.0.0.0/0            /* default/kubernetes:https */
    0     0 DNAT       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/kubernetes:https */ tcp to:172.30.47.189:443

Chain KUBE-SEP-JKPKL7GFGRUS3R5T (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  all  --  *      *       172.30.35.22         0.0.0.0/0            /* kube-system/kube-dns:dns-tcp */
    0     0 DNAT       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:dns-tcp */ tcp to:172.30.35.22:53

Chain KUBE-SEP-W7Z2VQWXN5OBAHCZ (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  all  --  *      *       172.30.35.22         0.0.0.0/0            /* kube-system/kube-dns:dns */
    0     0 DNAT       udp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:dns */ udp to:172.30.35.22:53

Chain KUBE-SERVICES (2 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-SVC-NPX46M4PTMTKRN6Y  tcp  --  *      *       0.0.0.0/0            100.64.0.1           /* default/kubernetes:https cluster IP */ tcp dpt:443
    0     0 KUBE-SVC-TCOU7JCQXEZGVUNU  udp  --  *      *       0.0.0.0/0            100.64.0.10          /* kube-system/kube-dns:dns cluster IP */ udp dpt:53
    0     0 KUBE-SVC-ERIFXISQEP7F7OF4  tcp  --  *      *       0.0.0.0/0            100.64.0.10          /* kube-system/kube-dns:dns-tcp cluster IP */ tcp dpt:53
    0     0 KUBE-SVC-JD5MR3NA4I4DYORP  tcp  --  *      *       0.0.0.0/0            100.64.0.10          /* kube-system/kube-dns:metrics cluster IP */ tcp dpt:9153
  174 10709 KUBE-NODEPORTS  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service nodeports; NOTE: this must be the last rule in this chain */ ADDRTYPE match dst-type LOCAL

Chain KUBE-SVC-ERIFXISQEP7F7OF4 (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-SEP-JKPKL7GFGRUS3R5T  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:dns-tcp -> 172.30.35.22:53 */ statistic mode random probability 0.50000000000
    0     0 KUBE-SEP-F34FWTZSD5CRXDSN  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:dns-tcp -> 172.30.67.252:53 */

Chain KUBE-SVC-JD5MR3NA4I4DYORP (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-SEP-E5VE4QQSILFWIGM4  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:metrics -> 172.30.35.22:9153 */ statistic mode random probability 0.50000000000
    0     0 KUBE-SEP-7X6AO62GIOXV3FVU  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:metrics -> 172.30.67.252:9153 */

Chain KUBE-SVC-NPX46M4PTMTKRN6Y (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-SEP-GQ5ILYDZNB4UO27Z  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/kubernetes:https -> 172.30.47.189:443 */

Chain KUBE-SVC-TCOU7JCQXEZGVUNU (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-SEP-W7Z2VQWXN5OBAHCZ  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:dns -> 172.30.35.22:53 */ statistic mode random probability 0.50000000000
    0     0 KUBE-SEP-2ZRLULZUW5ZRJPDH  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kube-system/kube-dns:dns -> 172.30.67.252:53 */
```

# 노드에서 기본 네트워크 정보 확인

![](images/2023-03-18-08-50-50.png)
> 그림 출처: [CloudNet@ Blog](https://gasidaseo.notion.site/AWS-EKS-VPC-CNI-1-POD-f89e3e5967b24f8c9aa5bfaab1a82ceb)

  > 네트워크 네임스페이스는 호스트와 파트로 나뉜다.
  > 특정한 파드(kube-proxy, aws-node)는 호스트(Root)의 IP를 그대로 사용한다.
  > t3.medium 의 경우 ENI 마다 최대 6개의 IP를 가질 수 있다
  > ENI0, ENI1 으로 2개의 ENI는 자신의 IP 이외에 추가적으로 5개의 보조 프라이빗 IP를 가질수 있다.
  > coredns 파드는 veth 으로 호스트에는 eniY@ifN 인터페이스와 파드에 eth0 과 연결되어 있다.

워커 노드인스턴스의 네트워크 정보 확인 : 프라이빗 IP와 보조 프라이빗 IP 확인

![](images/2023-03-19-09-17-38.png)

> 2주차 노션에는 192.168.x.x 대역대이던데 제껀 172.x.x.x 대역대로 나왔습니다.

* 보조 IPv4 주소를 파드가 사용하는지 확인

```shell
# ebs-csi-node 파드 IP 정보 확인
❯ kubectl get pod -n kube-system -l app=ebs-csi-node -owide
NAME                 READY   STATUS    RESTARTS   AGE   IP              NODE                  NOMINATED NODE   READINESS GATES
ebs-csi-node-55nxx   3/3     Running   0          16m   172.30.87.105   i-01cadf0d8d3c7a565   <none>           <none>
ebs-csi-node-h4gmp   3/3     Running   0          17m   172.30.54.154   i-0ad86f23f13499914   <none>           <none>
ebs-csi-node-hv2j2   3/3     Running   0          17m   172.30.42.74    i-0f395f78142396d9d   <none>           <none>

# 노드의 라우팅 정보 확인 >> EC2 네트워크 정보의 '보조 프라이빗 IPv4 주소'와 비교해보자
❯ ssh -i ~/.ssh/id_rsa ubuntu@api.$KOPS_CLUSTER_NAME ip -c route
default via 172.30.32.1 dev ens5 proto dhcp src 172.30.47.189 metric 100
172.30.32.0/19 dev ens5 proto kernel scope link src 172.30.47.189
172.30.32.1 dev ens5 proto dhcp scope link src 172.30.47.189 metric 100
172.30.50.245 dev enieb5ea8b4376 scope link
172.30.54.154 dev enid914a74f540 scope link

❯ ssh -i ~/.ssh/id_rsa ubuntu@$W1PIP ip -c route
default via 172.30.64.1 dev ens5 proto dhcp src 172.30.77.200 metric 100
172.30.64.0/19 dev ens5 proto kernel scope link src 172.30.77.200
172.30.64.1 dev ens5 proto dhcp scope link src 172.30.77.200 metric 100
172.30.67.252 dev eni037a5c81799 scope link
172.30.87.105 dev enie241f3eec46 scope link

❯ ssh -i ~/.ssh/id_rsa ubuntu@$W2PIP ip -c route
default via 172.30.32.1 dev ens5 proto dhcp src 172.30.62.109 metric 100
172.30.32.0/19 dev ens5 proto kernel scope link src 172.30.62.109
172.30.32.1 dev ens5 proto dhcp scope link src 172.30.62.109 metric 100
172.30.32.154 dev eni060476fcee4 scope link
172.30.35.22 dev eni3f9c32716a7 scope link
172.30.42.74 dev eni40c4034e65c scope link
```

* 테스트용 파드 생성: [nicolaka/netshoot](https://github.com/nicolaka/netshoot)

```shell
# [터미널1~2] 워커 노드 1~2 모니터링
❯ ssh -i ~/.ssh/id_rsa ubuntu@$W1PIP
ubuntu@i-01cadf0d8d3c7a565:~$ watch -d "ip link | egrep 'ens5|eni' ;echo;echo "[ROUTE TABLE]"; route -n | grep eni"

❯ ssh -i ~/.ssh/id_rsa ubuntu@$W2PIP
ubuntu@i-0f395f78142396d9d:~$ watch -d "ip link | egrep 'ens5|eni' ;echo;echo "[ROUTE TABLE]"; route -n | grep eni"

# 테스트용 파드 netshoot-pod 생성
❯ cat <<EOF | kubectl create -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: netshoot-pod
spec:
  replicas: 2
  selector:
    matchLabels:
      app: netshoot-pod
  template:
    metadata:
      labels:
        app: netshoot-pod
    spec:
      containers:
      - name: netshoot-pod
        image: nicolaka/netshoot
        command: ["tail"]
        args: ["-f", "/dev/null"]
      terminationGracePeriodSeconds: 0
EOF
deployment.apps/netshoot-pod created

# 파드 확인
❯ kubectl get pod -o wide
NAME                            READY   STATUS    RESTARTS   AGE   IP              NODE                  NOMINATED NODE   READINESS GATES
netshoot-pod-7757d5dd99-dc4f2   1/1     Running   0          72s   172.30.94.143   i-01cadf0d8d3c7a565   <none>           <none>
netshoot-pod-7757d5dd99-l5ccl   1/1     Running   0          72s   172.30.63.210   i-0f395f78142396d9d   <none>           <none>

❯ kubectl get pod -o=custom-columns=NAME:.metadata.name,IP:.status.podIP
NAME                            IP
netshoot-pod-7757d5dd99-dc4f2   172.30.94.143
netshoot-pod-7757d5dd99-l5ccl   172.30.63.210

# worker #1: ip link | egrep 'ens5|eni' ;echo;echo "[ROUTE TABLE]"; route -n | grep eni
Every 2.0s: ip link | egrep 'ens5|eni' ;echo;echo [ROUTE TABLE]; route...  i-01cadf0d8d3c7a565: Sun Mar 19 00:25:22 2023

2: ens5: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc mq state UP mode DEFAULT group default qlen 1000
3: enie241f3eec46@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc noqueue state UP mode DEFAULT group default
4: eni037a5c81799@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc noqueue state UP mode DEFAULT group default
6: enicced734b3bf@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc noqueue state UP mode DEFAULT group default

[ROUTE TABLE]
172.30.67.252   0.0.0.0         255.255.255.255 UH    0      0        0 eni037a5c81799
172.30.87.105   0.0.0.0         255.255.255.255 UH    0      0        0 enie241f3eec46
172.30.94.143   0.0.0.0         255.255.255.255 UH    0      0        0 enicced734b3bf

# worker #2: ip link | egrep 'ens5|eni' ;echo;echo "[ROUTE TABLE]"; route -n | grep eni
2: ens5: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc mq state UP mode DEFAULT group default qlen 1000
3: eni40c4034e65c@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc noqueue state UP mode DEFAULT group default
4: eni060476fcee4@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc noqueue state UP mode DEFAULT group default
5: eni3f9c32716a7@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc noqueue state UP mode DEFAULT group default
7: eni1831e60bd8d@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc noqueue state UP mode DEFAULT group default

[ROUTE TABLE]
172.30.32.154   0.0.0.0         255.255.255.255 UH    0      0        0 eni060476fcee4
172.30.35.22    0.0.0.0         255.255.255.255 UH    0      0        0 eni3f9c32716a7
172.30.42.74    0.0.0.0         255.255.255.255 UH    0      0        0 eni40c4034e65c
172.30.63.210   0.0.0.0         255.255.255.255 UH    0      0        0 eni1831e60bd8d
```

* 테스트용 파드 eniY 정보 확인 - 워커 노드 EC2

```shell
# 마지막 생성된 네임스페이스 정보 출력 -t net(네트워크 타입)
ubuntu@i-01cadf0d8d3c7a565:~$ sudo lsns -o PID,COMMAND -t net | awk 'NR>2 {print $1}' | tail -n 1
11247

# 마지막 생성된 네임스페이스 net PID 정보 출력 -t net(네트워크 타입)를 변수 지정
MyPID=$(sudo lsns -o PID,COMMAND -t net | awk 'NR>2 {print $1}' | tail -n 1)

# PID 정보로 파드 정보 확인
ubuntu@i-01cadf0d8d3c7a565:~$ sudo nsenter -t $MyPID -n ip -c addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
3: eth0@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc noqueue state UP group default
    link/ether 02:f4:6c:1d:96:ff brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.30.94.143/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::f4:6cff:fe1d:96ff/64 scope link
       valid_lft forever preferred_lft forever

ubuntu@i-01cadf0d8d3c7a565:~$ sudo nsenter -t $MyPID -n ip -c route
default via 169.254.1.1 dev eth0
169.254.1.1 dev eth0 scope link
```

* 테스트용 파드 접속(exec) 후 확인

```shell
❯ kubectl get pod -o wide
NAME                            READY   STATUS    RESTARTS   AGE   IP              NODE                  NOMINATED NODE   READINESS GATES
netshoot-pod-7757d5dd99-dc4f2   1/1     Running   0          72s   172.30.94.143   i-01cadf0d8d3c7a565   <none>           <none>
netshoot-pod-7757d5dd99-l5ccl   1/1     Running   0          72s   172.30.63.210   i-0f395f78142396d9d   <none>           <none>

# 테스트용 파드 접속(exec) 후 Shell 실행
❯ kubectl exec -it netshoot-pod-7757d5dd99-dc4f2 -- zsh
/root/.zshrc:source:76: no such file or directory: /root/.oh-my-zsh/oh-my-zsh.sh
                    dP            dP                           dP
                    88            88                           88
88d888b. .d8888b. d8888P .d8888b. 88d888b. .d8888b. .d8888b. d8888P
88'  `88 88ooood8   88   Y8ooooo. 88'  `88 88'  `88 88'  `88   88
88    88 88.  ...   88         88 88    88 88.  .88 88.  .88   88
dP    dP `88888P'   dP   `88888P' dP    dP `88888P' `88888P'   dP

Welcome to Netshoot! (github.com/nicolaka/netshoot)



netshoot-pod-7757d5dd99-dc4f2#

# 아래부터는 pod-1 Shell 에서 실행 : 네트워크 정보 확인
netshoot-pod-7757d5dd99-dc4f2# ip -c addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
3: eth0@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc noqueue state UP group default
    link/ether 02:f4:6c:1d:96:ff brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.30.94.143/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::f4:6cff:fe1d:96ff/64 scope link
       valid_lft forever preferred_lft forever

netshoot-pod-7757d5dd99-dc4f2# ip -c route
default via 169.254.1.1 dev eth0
169.254.1.1 dev eth0 scope link

netshoot-pod-7757d5dd99-dc4f2# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         169.254.1.1     0.0.0.0         UG    0      0        0 eth0
169.254.1.1     0.0.0.0         255.255.255.255 UH    0      0        0 eth0


# ping -c 1 <pod-2 IP>
netshoot-pod-7757d5dd99-dc4f2# ping -c 1 172.30.63.210
PING 172.30.63.210 (172.30.63.210) 56(84) bytes of data.
64 bytes from 172.30.63.210: icmp_seq=1 ttl=62 time=1.55 ms

--- 172.30.63.210 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 1.554/1.554/1.554/0.000 ms

netshoot-pod-7757d5dd99-dc4f2# ps
PID   USER     TIME  COMMAND
    1 root      0:00 tail -f /dev/null
    7 root      0:00 zsh
   18 root      0:00 ps

netshoot-pod-7757d5dd99-dc4f2# cat /etc/resolv.conf
search default.svc.cluster.local svc.cluster.local cluster.local ap-northeast-2.compute.internal
nameserver 100.64.0.10
options ndots:5
----------------------------

# 파드2 Shell 실행
❯ kubectl exec -it netshoot-pod-7757d5dd99-l5ccl -- ip -c addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
3: eth0@if7: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc noqueue state UP group default
    link/ether ea:41:03:be:90:41 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.30.63.210/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::e841:3ff:febe:9041/64 scope link
       valid_lft forever preferred_lft forever
```

* 실습 정리

```shell
❯ kops delete cluster --yes 

❯ aws s3 rm s3://koala-k8s-s3 --recursive
delete: s3://koala-k8s-s3/ejpark.link/instancegroup/nodes-ap-northeast-2a
delete: s3://koala-k8s-s3/ejpark.link/config
delete: s3://koala-k8s-s3/ejpark.link/instancegroup/nodes-ap-northeast-2c
delete: s3://koala-k8s-s3/ejpark.link/instancegroup/master-ap-northeast-2a

❯ aws s3 rb s3://koala-k8s-s3
remove_bucket: koala-k8s-s3

❯ aws s3 ls
```

# 노드 간 파드 통신

**TBD**

---

2주차에 사용된 patch 를 하면 뭐가 달라질까? max_pods 를 100 으로 늘리는 것 말고 다른 옵션은 무슨 뜻일까?
