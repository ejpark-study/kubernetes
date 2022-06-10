# Database Operator In Kubernetes study (DOIK) 스터디 중간 과제

가시다님 최고의 스터디인 Kubernetes Advanced Networking Study (KANS)에 이어서 Database Operator 를 사용하는 방법에 관한 스터디에 참여하고 있다. 내가 궁금한 부분은 맨 마지막주에 있는 Elasticsearch Operator 인데, 듣다가 보니 도움이 많이 되었다. 특히 나 같은 경우에는 데이터를 저장해야 하는 서비스를 Kubernetes 에서 하기엔 쫄보라서 지금까지는 docker 로 Elasticsearch, Mysql, MongoDB 를 운영하였다. 이번 스터디에서 장애를 발생하고 복구하는 것을 보니 다음 프로젝트에는 Operator 를 사용해 보려고 한다. 

듣고 싶은 Elasticsearch Operator 를 듣기 위해서는 중간과제를 제출해야 하는데, 최대한 업무와 관련있는 주제를 찾다가 오늘에서야 주제를 잡고 이렇게 작성한다. 내부에서는 MLOps Pipeline 개발에 MinIO, RebbitMQ 사용하고 있어서, 이번 중간 과제 주제로 MinIO 를 기존 방식인 docker 방식에서 MinIO Operator 를 사용하는 방식으로 변환하는 과정을 정리하고자 한다. 문제는 저번주 부터 테스트해보고 있는데, OpenShift 에서는 MinIO 에서 공식 지원하는 Helm Operator 방식이 설치되지 않아 중간 과제 작성이 늦어졌다.

# Prepare AWS Stack

스터디 실습환경은 아래와 같다.

![](https://gasidaseo.notion.site/image/https%3A%2F%2Fs3-us-west-2.amazonaws.com%2Fsecure.notion-static.com%2F94db7f7e-8c9e-467a-a472-ccfd461784b1%2FUntitled.png?table=block&id=95885b1b-017c-43f9-b238-79a540fab442&spaceId=a6af158e-5b0f-4e31-9d12-0d0b2805956a&width=1630&userId=&cache=v2)

* [(공개) 바닐라 쿠베네티스 실습 환경 배포 가이드](https://gasidaseo.notion.site/db0869d191ec4e4d90b1c9bb722a7175)

## aws stack 생성

ipinfo.io/ip 로 현재 접속중인 PC 의 public ip 로만 접속할 수 있도록 aws stack 을 생성한다. [start-stack](start-stack.ps1) 스터디 실습 환경은 myk8s 인데 doik 로 변경하였다.

```shell
curl -o doik.yaml "https://s3.ap-northeast-2.amazonaws.com/cloudformation.cloudneta.net/K8S/cloudneta-k8s-4.yaml"

# create stack
aws cloudformation deploy --template-file doik.yaml --stack-name doik --parameter-overrides KeyName=default SgIngressCidr=$(curl -s ipinfo.io/ip)/32
```

## aws stack 삭제

[stop-stack](stop-stack.ps1)

```shell
# list stack
aws cloudformation list-stacks

# delete stack
aws cloudformation delete-stack --stack-name doik
```

## master node 접속

* [aws console](https://ap-northeast-2.console.aws.amazon.com/cloudformation/home?region=ap-northeast-2)

master node 의 ip 주소가 생성할 때마다 달라져서 아래와 같은 접속 [스크립트](master.ps1)를 작성하였다.

```shell
# check node ip
aws cloudformation describe-stacks | Select-String MasterNodeIP

# ssh connect
$node_ip=$(aws cloudformation describe-stacks | Select-String MasterNodeIP).Line.split('IP').trim()[-1]
ssh -i default.pem ubuntu@$node_ip
```

# k9s install

스터디에서는 kubeopsview 를 사용하는데, 난 아직 k9s 가 익숙해서 설치했다.

```shell
wget "https://github.com/derailed/k9s/releases/download/v0.25.18/k9s_Linux_x86_64.tar.gz" -O /tmp/k9s_Linux_x86_64.tar.gz
tar xvfz /tmp/k9s_Linux_x86_64.tar.gz -C /tmp && mv /tmp/k9s /usr/bin/k9s
rm -f /tmp/k9s_Linux_x86_64.tar.gz
```

# MinIO Console

불과 6개월 전만 하더라도 이런 그래프는 없었는데, 엄청나게 변경됬다.

![](https://github.com/minio/operator/raw/master/docs/images/console-dashboard.png)

# MinIO with Docker

MinIO 예전 버전중 하나에서 timezone 이슈가 있어 volumne 에 host timezone 을 넣어 준다. MinIO client 인 mc 에서 접근시 timezone 이 맞지 않다는 에러 메세지가 출력되면서 접속이 안되는 이슈가 있었다. 

```shell
export MINIO_DATA=~/minio-data

docker run \
  --detach --restart unless-stopped \
  --name minio \
  --hostname minio \
  --publish 80:80 \
  --publish 9000:9000 \
  --env "MINIO_ROOT_USER=minio" \
  --env "MINIO_ROOT_PASSWORD=minio1234" \
  --volume "${MINIO_DATA}:/data:rw" \
  --volume /etc/timezone:/etc/timezone:ro \
  --volume /etc/localtime:/etc/localtime:ro \
  quay.io/minio/minio:RELEASE.2022-05-08T23-50-31Z \
    server --address "0.0.0.0:9000" --console-address "0.0.0.0:80" /data
```

# MinIO valina kuberentes

MinIO 공식 문서에는 두가지 버전의 Helm이 있다. 그중 Operator 를 쓰지 않는 Helm 에서 아래 배포 스크립트를 추출하였다.

## secret 을 위한 admin 암호 변환

```shell
❯ echo -n minio | base64
bWluaW8=

❯ echo -n minio1234 | base64
bWluaW8xMjM0
```

## MinIO 배포 스크립트

MinIO 는 client 에서 접근하는 9000번 포트와 웹 콘솔화면에 접근하는 9001번 포트가 있다. 여기서는 웹 콘솔 포트만 열었다. 아래 yaml 파일은 공식 helm chart 에서 template 으로 뽑아 냈다. 

```shell
cat <<EOF | kubectl apply -f -
---
# Secret
apiVersion: v1
kind: Secret
metadata:
  name: minio
  labels:
    app: minio
type: Opaque
data:
  rootUser: "bWluaW8="
  rootPassword: "bWluaW8xMjM0"
---
# Service
apiVersion: v1
kind: Service
metadata:
  name: minio-console
  labels:
    app: minio
spec:
  type: ClusterIP
  ports:
    - name: http
      port: 9001
      protocol: TCP
      targetPort: 9001
  selector:
    app: minio
---
# StatefulSet
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: minio
  labels:
    app: minio
spec:
  serviceName: minio
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      name: minio
      labels:
        app: minio
    spec:
      containers:
        - name: minio
          image: quay.io/minio/minio:RELEASE.2022-05-08T23-50-31Z
          imagePullPolicy: IfNotPresent
          command: [ "/bin/sh",
            "-ce",
            "/usr/bin/docker-entrypoint.sh minio server --address :9000 --console-address :9001 /export" ]
          volumeMounts:
            - name: export
              mountPath: /export
          ports:
            - name: http
              containerPort: 9000
            - name: http-console
              containerPort: 9001
          env:
            - name: MINIO_ROOT_USER
              valueFrom:
                secretKeyRef:
                  name: minio
                  key: rootUser
            - name: MINIO_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: minio
                  key: rootPassword
            - name: MINIO_PROMETHEUS_AUTH_TYPE
              value: "public"
          resources:
            requests:
              memory: 8Gi
      volumes:
        - name: minio-user
          secret:
            secretName: minio
  volumeClaimTemplates:
    - metadata:
        name: export
      spec:
        accessModes: [ "ReadWriteOnce" ]
        resources:
          requests:
            storage: 100Gi
EOF
```

MetalLB 와 같은 Loadbalancer 가 있다면 위와 같이 하고 Ingress 로 접근하면 간편하지만, 난 아래와 같이 Service 에 ExternalIPs 를 설정해서 Service 로 접근하는 것을 (간편해서?) 선호한다. NodePort를 쓰는건 좀 꺼려져서 되도록이면 그 방식은 안쓰려고 한다.

```shell
---
# Service
apiVersion: v1
kind: Service
metadata:
  name: minio-console
  labels:
    app: minio
spec:
  type: LoadBalancer
  ExternalIPs:
    - <MasterNodeIP or one of WorkerNodeIP>
  ports:
    - name: http
      port: 9001
      protocol: TCP
      targetPort: 9001
  selector:
    app: minio
```

## [번외] Kubernetes yaml 을 Helm 으로 변경

### skel 생성

helm 명령어로 생성할수 있는데 ServiceAccount 와 같은 부수적인 것도 같이 생성되서 간단하게 테스트할 때는 이 방법을 사용한다.

```shell
mkdir -p helm/templates
touch helm/values.yaml 

cat <<EOF > helm/Chart.yaml
apiVersion: v1
name: MinIO my helm chart
description: A Helm chart for MinIO
type: application
version: 1.0.0
appVersion: 1.0.0
EOF
```

### kubernetes yaml 파일 분리 

기존 kubernetes yaml 파일을 리소스별로 분리해서 helm/templates 폴더에 저장한다.

```shell 
cat <<EOF > helm/templates/Secret.yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: minio
  labels:
    app: minio
type: Opaque
data:
  rootUser: "bWluaW8="
  rootPassword: "bWluaW8xMjM0"
EOF
```

### template 랜더링

helm template 명령으로 랜더링 하면서 templates 안의 파일을 변수화 한다.

```shell
❯ helm template dev .
```

### values.yaml 변수화 및 반복문

예를 들어 Secret 의 root 패스워드를 변수화하는 경우 values.yaml 에 아래와 같이 설정한다.

```yaml
secret:
  rootUser: "bWluaW8="
  rootPassword: "bWluaW8xMjM0"
```

templates/Secret.yaml 파일에서 변수부분을 아래와 같이 수정한다.

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: minio
  labels:
    app: minio
type: Opaque
data:
  rootUser: {{ $.Values.secret.rootUser }}
  rootPassword: {{ $.Values.secret.rootUser }}
```

json 으로 랜더링 할수도 있다.

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: minio
  labels:
    app: minio
type: Opaque
data:
  {{- toYaml $.Values.secret | nindent 2 }}
```

### 디버깅

에러가 나는 경우 --debug 옵션으로 에러 위치를 확인하면서 변수화 한다.

```shell
❯ helm template dev . --debug
```

# MinIO Helm

MinIO 에서는 아래와 같이 Operator 와 Helm Chart 방식이 존재한다.

![](MinIO-Deploy-on-K8S.png)

* [Deploy MinIO on Kubernetes](https://docs.min.io/docs/deploy-minio-on-kubernetes.html)

helm chart 를 그데로 사용하기 위해 NodePort 32900 으로 배포했다.

```shell 
helm repo add minio https://charts.min.io/

helm install \
  --namespace minio \
  --set rootUser=minio,rootPassword=minio123,mode=standalone,replicas=1,persistence.size=100Gi,service.type=NodePort,service.nodePort=32900 \
  --generate-name minio/minio
```

# MinIO Operator

![](https://github.com/minio/operator/raw/master/docs/images/architecture.png)

* [MinIO Operator](https://github.com/minio/operator/blob/master/README.md)

```shell
kubectl krew update
kubectl krew install minio

kubectl minio init
```

# MinIO Operator based Helm 

TODO

# RebbitMQ

* [rabbitmq operator](https://www.rabbitmq.com/kubernetes/operator/operator-overview.html)

TODO

# issue 

## warning: LF will be replaced by CRLF in doik/doik.yaml.

윈도우에서 git 작업하다가 보면 이런 메세지가 성가신다. 아래와 같이 autocrlf 를 false 설정한다.

```shell
❯ git config core.autocrlf false
```

## lfs 설치

이미지 등의 바이너리 파일은 버전 추적이 안되도록 lfs 설정을 한다.

```shell
❯ git lfs install
❯ git lfs track *.png
```