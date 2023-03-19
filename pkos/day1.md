**"24단계 실습으로 정복하는 쿠버네티스" 책을 기준하여 정리하였습니다.**

![](images/pkos-1.png)

# 1주차 - AWS kOps 설치 및 기본 사용

AWS Kops는 AWS에서 쉽게 쿠버네티스를 설치할수 있도록 도와주는 도구라고 합니다. AWS 의 DNS 서비스(Router 53)와 연동해서 DNS 레코드를 괸리해 준다는 점이 인상 깊었습니다.

* 시스템 구성
![](images/2023-03-08-12-06-31.png)

처음 이해가 안됬던 부분은 myVPC 였습니다. 스터디에서 내용중에 PC 성능이 필요한 부분이 있는데, 그것 때문이라고 합니다.

DNS 를 꼭 발급받으라고 했었는데, 1주차때 왜 그런지 알게 되었습니다. kOps 배포시 DNS 레코드로 연동되는 부분이 있는데, 그게 원할하게 실행되려면 AWS Router 53에서 받은 DNS 가 있어야 되나봅니다. 저는 수업중에 제일 싼거로 빠르게 구입했습니다.

# 사전 준비

* kubectl, kOps, aws cli 설치
  * [kops install](https://kubernetes.io/docs/setup/production-environment/tools/kops/)
  * [aws cli install](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  * [kubectl install](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)

```shell
# kubectl
❯ curl -s -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# aws cli
❯ curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
❯ unzip awscliv2.zip
❯ sudo ./aws/install

# kOps
❯ curl -LO https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64
```

# aws login

## IAM 생성

* [aws console](https://console.aws.amazon.com)

AWS 웹 콘솔에서 "IAM" 검색후 "IAM dashboard"에서 access key를 생성합니다.

![](images/2023-03-08-12-37-27.png)

![](images/2023-03-08-12-39-28.png)

꼭 "Download .csv file"를 해서 키를 다운로드 받아야 합니다.

![](images/2023-03-08-12-41-04.png)

## aws cli login

```shell
❯ aws configure
AWS Access Key ID [None]: AKIA5...
AWS Secret Access Key [None]: CVNa2...
Default region name [None]: ap-northeast-2 # 서울 리전
Default output format [None]: text
```

# aws bucket 생성

kOps 는 클러스터의 설정을 저장할 수 있는 S3 버킷이 필요하나봅니다. 하나 생성해 줍니다.

```shell
REGION=ap-northeast-2  # 서울 리전 사용

❯ aws s3 mb s3://koala-k8s-s3 --region $REGION
make_bucket: koala-k8s-s3

❯ aws s3 ls
2023-03-08 12:44:33 koala-k8s-s3
```

# Router 53 에서 DNS 생성

AWS web console 에서 "Router 53" 검색합니다.

![](images/2023-03-08-12-55-14.png)

"Registered Domains" 메뉴에서 "Register Domain" 버튼으로 DNS 를 생성합니다.

![](images/2023-03-08-12-56-42.png)

10분 정도후 "Hosted zones"에서 생성된 도메인으로 호스트가 생성되었는지 확인합니다. 만약 없다면 KOps 실행이 안될 수도 있습니다.

![](images/2023-03-08-13-01-47.png)

# kubernetes deploy

* [yh install](https://github.com/andreazorzetto/yh/releases)

```shell
# check version
❯ kubectl version --client=true -o yaml | yh

clientVersion:
  buildDate: "2023-01-18T15:58:16Z"
  compiler: gc
  gitCommit: 8f94681cd294aa8cfd3407b8191f6c70214973a4
  gitTreeState: clean
  gitVersion: v1.26.1
  goVersion: go1.19.5
  major: "1"
  minor: "26"
  platform: linux/amd64
kustomizeVersion: v4.5.7

❯ kops version
Client version: 1.25.3 (git-v1.25.3)

❯ aws --version
aws-cli/2.11.0 Python/3.11.2 Linux/5.15.57.1-microsoft-standard-WSL2+ exe/x86_64.ubuntu.22 prompt/off

# check ssh key
❯ ls ~/.ssh/id_rsa
/home/ubuntu/.ssh/id_rsa

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
    --kubernetes-version "1.24.10"
I0308 13:03:50.186831    3041 create_cluster.go:831] Using SSH public key: /home/ubuntu/.ssh/id_rsa.pub
I0308 13:03:52.130514    3041 new_cluster.go:1279]  Cloud Provider ID = aws
I0308 13:03:52.262512    3041 subnets.go:185] Assigned CIDR 172.30.32.0/19 to subnet ap-northeast-2a
I0308 13:03:52.262549    3041 subnets.go:185] Assigned CIDR 172.30.64.0/19 to subnet ap-northeast-2c
Previewing changes that will be made:

(...)

Cluster configuration has been created.

Suggestions:
 * list clusters with: kops get cluster
 * edit this cluster with: kops edit cluster ejpark.link
 * edit your node instance group: kops edit ig --name=ejpark.link nodes-ap-northeast-2a
 * edit your master instance group: kops edit ig --name=ejpark.link master-ap-northeast-2a

Finally configure your cluster with: kops update cluster --name ejpark.link --yes --admin

❯ kops update cluster --name ejpark.link --yes --admin

(...)

Cluster is starting.  It should be ready in a few minutes.

Suggestions:
 * validate cluster: kops validate cluster --wait 10m
 * list nodes: kubectl get nodes --show-labels
 * ssh to the master: ssh -i ~/.ssh/id_rsa ubuntu@api.ejpark.link
 * the ubuntu user is specific to Ubuntu. If not using Ubuntu please use the appropriate user based on your OS.
 * read about installing addons at: https://kops.sigs.k8s.io/addons.
```

> 저 같은 경우에는 "kops update cluster --name ejpark.link --yes --admin" 명령으로 클러스터리를 실행해줘야 했습니다.

# EC2 dashboard 에서 확인

![](images/2023-03-08-13-08-32.png)

Router 53의 DNS 레코드에 kOps Control-Plain의 레코드가 등록되는 점이 인상 깊었습니다. 가시다님께서 외부에서 접근할수 있도록 하기 위해서라더군요.

![](images/2023-03-08-13-11-12.png)

DNS 레코드를 조회하는 실습이 있었는데, 제 WSL2 에서는 안되네요.

```shell
❯ MyDomain=ejpark.link

❯ aws route53 list-resource-record-sets --hosted-zone-id "${MyDnzHostedZoneId}" --query "ResourceRecordSets[?Type == 'A'].Name" --output text

An error occurred (NoSuchHostedZone) when calling the ListResourceRecordSets operation: No hosted zone found with ID: rrset
```

* kOps 설치 확인

```shell
❯ aws ec2 describe-instances --query "Reservations[*].Instances[*].{PublicIPAdd:PublicIpAddress,PrivateIPAdd:PrivateIpAddress,InstanceName:Tags[?Key=='Name']|[0].Value,Status:State.Name}" --filters Name=instance-state-name,Values=running --output table
---------------------------------------------------------------------------------------------
|                                     DescribeInstances                                     |
+---------------------------------------------+----------------+----------------+-----------+
|                InstanceName                 | PrivateIPAdd   |  PublicIPAdd   |  Status   |
+---------------------------------------------+----------------+----------------+-----------+
|  nodes-ap-northeast-2c.ejpark.link          |  172.30.88.121 |  15.164.171.58 |  running  |
|  nodes-ap-northeast-2a.ejpark.link          |  172.30.35.28  |  43.201.146.90 |  running  |
|  master-ap-northeast-2a.masters.ejpark.link |  172.30.42.49  |  54.180.140.70 |  running  |
+---------------------------------------------+----------------+----------------+-----------+

❯ kubectl get pod -n kube-system -o=custom-columns=NAME:.metadata.name,IP:.status.podIP,STATUS:.status.phase
NAME                                          IP              STATUS
aws-cloud-controller-manager-9wvrd            172.30.42.49    Running
aws-node-8svb4                                172.30.35.28    Running
aws-node-fvmrl                                172.30.42.49    Running
aws-node-lv6dj                                172.30.88.121   Running
coredns-6897c49dc4-6jptp                      172.30.40.54    Running
coredns-6897c49dc4-jdnj7                      172.30.85.192   Running
coredns-autoscaler-5685d4f67b-qftlr           172.30.39.186   Running
dns-controller-844ddc7657-pjp5v               172.30.42.49    Running
ebs-csi-controller-776c4cfdf6-w5h2g           172.30.32.37    Running
ebs-csi-node-4qrds                            172.30.58.56    Running
ebs-csi-node-m99md                            172.30.63.172   Running
ebs-csi-node-rqfd5                            172.30.82.54    Running
etcd-manager-events-i-056638a4d94755a96       172.30.42.49    Running
etcd-manager-main-i-056638a4d94755a96         172.30.42.49    Running
kops-controller-hw2nk                         172.30.42.49    Running
kube-apiserver-i-056638a4d94755a96            172.30.42.49    Running
kube-controller-manager-i-056638a4d94755a96   172.30.42.49    Running
kube-proxy-i-0063066ba296c2740                172.30.88.121   Running
kube-proxy-i-056638a4d94755a96                172.30.42.49    Running
kube-proxy-i-061b79e91932109ea                172.30.35.28    Running
kube-scheduler-i-056638a4d94755a96            172.30.42.49    Running

# kops 클러스터 정보 확인
❯ kops get cluster
NAME            CLOUD   ZONES
ejpark.link     aws     ap-northeast-2a,ap-northeast-2c

❯ kops get ig
NAME                    ROLE    MACHINETYPE     MIN     MAX     ZONES
master-ap-northeast-2a  Master  t3.medium       1       1       ap-northeast-2a
nodes-ap-northeast-2a   Node    t3.medium       1       1       ap-northeast-2a
nodes-ap-northeast-2c   Node    t3.medium       1       1       ap-northeast-2c    

❯ kops get instances
ID                      NODE-NAME               STATUS          ROLES   STATE   INTERNAL-IP     INSTANCE-GROUP         MACHINE-TYPE
i-0063066ba296c2740     i-0063066ba296c2740     UpToDate        node            172.30.88.121   nodes-ap-northeast-2c.ejpark.link               t3.medium
i-056638a4d94755a96     i-056638a4d94755a96     UpToDate        master          172.30.42.49    master-ap-northeast-2a.masters.ejpark.link      t3.medium
i-061b79e91932109ea     i-061b79e91932109ea     UpToDate        node            172.30.35.28    nodes-ap-northeast-2a.ejpark.link               t3.medium

❯ kubectl get nodes
NAME                  STATUS   ROLES           AGE     VERSION
i-0063066ba296c2740   Ready    node            7m28s   v1.24.10
i-056638a4d94755a96   Ready    control-plane   8m57s   v1.24.10
i-061b79e91932109ea   Ready    node            7m29s   v1.24.10

# CRI 컨테이너 런타임이 무엇인가요?
❯ kubectl get nodes -o wide
NAME                  STATUS   ROLES           AGE     VERSION    INTERNAL-IP     EXTERNAL-IP     OS-IMAGE             KERNEL-VERSION    CONTAINER-RUNTIME
i-0063066ba296c2740   Ready    node            7m53s   v1.24.10   172.30.88.121   15.164.171.58   Ubuntu 20.04.5 LTS   5.15.0-1028-aws   containerd://1.6.10
i-056638a4d94755a96   Ready    control-plane   9m22s   v1.24.10   172.30.42.49    54.180.140.70   Ubuntu 20.04.5 LTS   5.15.0-1028-aws   containerd://1.6.10
i-061b79e91932109ea   Ready    node            7m54s   v1.24.10   172.30.35.28    43.201.146.90   Ubuntu 20.04.5 LTS   5.15.0-1028-aws   containerd://1.6.10
```

# 워커 노드 접속

```shell
# 워커 노드 Public IP 확인
❯ aws ec2 describe-instances --query "Reservations[*].Instances[*].{PublicIPAdd:PublicIpAddress,InstanceName:Tags[?Key=='Name']|[0].Value}" --filters Name=instance-state-name,Values=running --output table
-----------------------------------------------------------------
|                       DescribeInstances                       |
+---------------------------------------------+-----------------+
|                InstanceName                 |   PublicIPAdd   |
+---------------------------------------------+-----------------+
|  nodes-ap-northeast-2c.ejpark.link          |  15.164.171.58  |
|  nodes-ap-northeast-2a.ejpark.link          |  43.201.146.90  |
|  master-ap-northeast-2a.masters.ejpark.link |  54.180.140.70  |
+---------------------------------------------+-----------------+

❯ W1PIP=15.164.171.58

# 워커 노드 SSH 접속
❯ ssh -i ~/.ssh/id_rsa ubuntu@$W1PIP
Welcome to Ubuntu 20.04.5 LTS (GNU/Linux 5.15.0-1028-aws x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Wed Mar  8 04:19:39 UTC 2023

  System load:  0.16               Processes:             122
  Usage of /:   2.8% of 123.87GB   Users logged in:       0
  Memory usage: 13%                IPv4 address for ens5: 172.30.88.121
  Swap usage:   0%                 IPv4 address for ens6: 172.30.95.243

(...)

/usr/bin/xauth:  file /home/ubuntu/.Xauthority does not exist
To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

ubuntu@i-0063066ba296c2740:~$ lsblk
NAME         MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
loop0          7:0    0  24.4M  1 loop /snap/amazon-ssm-agent/6312
loop1          7:1    0  63.3M  1 loop /snap/core20/1778
loop2          7:2    0  55.6M  1 loop /snap/core18/2667
loop3          7:3    0  91.9M  1 loop /snap/lxd/24061
loop4          7:4    0  49.6M  1 loop /snap/snapd/17883
nvme0n1      259:0    0   128G  0 disk
├─nvme0n1p1  259:1    0 127.9G  0 part /
├─nvme0n1p14 259:2    0     4M  0 part
└─nvme0n1p15 259:3    0   106M  0 part /boot/efi
```

# ExternalDNS

![ExternalDNS](images/2023-03-08-18-52-11.png)

출처: [A Self-hosted external DNS resolver for Kubernetes.](https://edgehog.blog/a-self-hosted-external-dns-resolver-for-kubernetes-111a27d6fc2c)

* ExternalDNS Addon 설치: [ExternalDNS Addon](https://github.com/kubernetes-sigs/external-dns)

```bash
# 모니터링
watch -d kubectl get pod -A

# 정책 생성 -> 마스터/워커노드에 정책 연결
curl -s -O https://s3.ap-northeast-2.amazonaws.com/cloudformation.cloudneta.net/AKOS/externaldns/externaldns-aws-r53-policy.json

aws iam create-policy --policy-name AllowExternalDNSUpdates --policy-document file://externaldns-aws-r53-policy.json

# ACCOUNT_ID 변수 지정
export ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)

# EC2 instance profiles 에 IAM Policy 추가(attach)
aws iam attach-role-policy --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/AllowExternalDNSUpdates --role-name masters.$KOPS_CLUSTER_NAME

aws iam attach-role-policy --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/AllowExternalDNSUpdates --role-name nodes.$KOPS_CLUSTER_NAME

# 설치
kops edit cluster
--------------------------
spec:
  certManager:
    enabled: true
  externalDns:
    provider: external-dns
--------------------------

# 업데이트 적용
kops update cluster --yes && echo && sleep 3 && kops rolling-update cluster

# externalDns 컨트롤러 파드 확인
kubectl get pod -n kube-system -l k8s-app=external-dns
NAME                            READY   STATUS    RESTARTS   AGE
external-dns-66969c4497-wbs5p   1/1     Running   0          8m53s
```

## mario 서비스에 도메인 연결 실습: [도메인체크](https://www.whatsmydns.net/)

```bash
# CLB에 ExternanDNS 로 도메인 연결
kubectl annotate service mario "external-dns.alpha.kubernetes.io/hostname=mario.$KOPS_CLUSTER_NAME"

# 확인
dig +short mario.$KOPS_CLUSTER_NAME
kubectl logs -n kube-system -l k8s-app=external-dns

# 웹 접속 주소 확인 및 접속
echo -e "Maria Game URL = http://mario.$KOPS_CLUSTER_NAME"

# 도메인 체크
echo -e "My Domain Checker = https://www.whatsmydns.net/#A/mario.$KOPS_CLUSTER_NAME"
```

* AWS Route53 A 레코드 확인



* 실습 완료 후 mario 게임 삭제

```bash
kubectl delete deploy,svc mario
```

[Amazon EKS Multi Cluster Upgrade with ExternalDNS](https://heuristicwave.github.io/EKS_Upgrade)

# 실습 정리

```shell
❯ kops delete cluster --yes
TYPE                    NAME                                                                    ID
autoscaling-config      master-ap-northeast-2a.masters.ejpark.link                              lt-0e8205d0b2e1659ba

(...)

dhcp-options:dopt-01e133453cd0bf81d     ok
Deleted kubectl config for ejpark.link

Deleted cluster: "ejpark.link"
```
