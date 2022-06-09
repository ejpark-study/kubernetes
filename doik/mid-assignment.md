# Database Operator In Kubernetes study (DOIK) 스터디 중간 과제

가시다님 최고의 스터디인 Kubernetes Advanced Networking Study (KANS)에 이어서 Database Operator 를 사용하는 방법에 관한 스터디에 참여하고 있다. 내가 궁금한 부분은 맨 마지막주에 있는 Elasticsearch Operator 인데, 듣다가 보니 도움이 많이 되었다. 특히 나 같은 경우에는 데이터를 저장해야 하는 서비스를 Kubernetes 에서 하기엔 쫄보라서 지금까지는 docker 로 Elasticsearch, Mysql, MongoDB 를 운영하였다. 이번 스터디에서 장애를 발생하고 복구하는 것을 보니 다음 프로젝트에는 Operator 를 사용해 보려고 한다. 

듣고 싶은 Elasticsearch Operator 를 듣기 위해서는 중간과제를 제출해야 하는데, 최대한 업무와 관련있는 주제를 찾다가 오늘에서야 주제를 잡고 이렇게 작성한다. 내부에서는 MLOps Pipeline 개발에 Minio와 RebbitMQ 사용하고 있어서, 이번 중간 과제 주제로 Minio 를 기존 방식인 docker 방식에서 Minio Operator 를 사용하는 방식으로 변환하는 과정을 정리하고자 한다. 문제는 저번주 부터 테스트해보고 있는데, OpenShift 에서는 Minio 에서 공식 지원하는 Helm Operator 방식이 설치되지 않아 중간 과제 작성이 늦어졌다.

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

```shell
# list stack
aws cloudformation list-stacks

# delete stack
aws cloudformation delete-stack --stack-name doik
```

## master node 접속

* [aws console](https://ap-northeast-2.console.aws.amazon.com/cloudformation/home?region=ap-northeast-2)

master node 의 ip 주소가 생성할때마다 달라져서 아래와 같은 [스크립트](master.ps1)를 작성하였다.

```shell
# check node ip
aws cloudformation describe-stacks

aws cloudformation describe-stacks | Select-String MasterNodeIP

# ssh connect
$node_ip=$(aws cloudformation describe-stacks | Select-String MasterNodeIP).Line.split('IP').trim()[-1]
ssh -i default.pem ubuntu@$node_ip
```

# k9s install

스터디에서는 kubeopsview 를 사용하는데 난 아직 k9s 가 익숙해서 설치해 줬다. 

```shell
wget "https://github.com/derailed/k9s/releases/download/v0.25.18/k9s_Linux_x86_64.tar.gz" -O /tmp/k9s_Linux_x86_64.tar.gz
tar xvfz /tmp/k9s_Linux_x86_64.tar.gz -C /tmp && mv /tmp/k9s /usr/bin/k9s
rm -f /tmp/k9s_Linux_x86_64.tar.gz
```

# start kubeopsview

```shell
kubectl apply -k DOIK/kubeopsview/

KUBEOPSVIEW=$(curl -s ipinfo.io/ip):$(kubectl get svc -n kube-system kube-ops-view -o jsonpath="{.spec.ports[0].nodePort}")
echo -e "Kube Ops View URL = http://$KUBEOPSVIEW"

google-chrome "http://$KUBEOPSVIEW"
```

# minio docker

```shell
docker run \
  --detach --restart unless-stopped \
  --name minio \
  --hostname minio \
  --publish 80:80 \
  --publish 9000:9000 \
  --env "MINIO_ROOT_USER=minio" \
  --env "MINIO_ROOT_PASSWORD=minio2022" \
  --volume "${DATA_PATH}:/data:rw" \
  --volume /etc/timezone:/etc/timezone:ro \
  --volume /etc/localtime:/etc/localtime:ro \
  registry.web.boeing.com/bketc-mlops/library/minio:RELEASE.2022-05-08T23-50-31Z \
    server --address "0.0.0.0:9000" --console-address "0.0.0.0:80" /data
```

# minio valina kuberentes


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
  rootUser: "aGFuZHNvbg=="
  rootPassword: "aGFuZHNvbjIwMjI="
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

# minio helm

# minio operator

# minio operator based helm 


# RebbitMQ

* [rabbitmq operator](https://www.rabbitmq.com/kubernetes/operator/operator-overview.html)

# issue 

## warning: LF will be replaced by CRLF in doik/doik.yaml.

윈도우에서 git 작업하다가 보면 이런 메세지가 성가신다. 

```shell
❯  git config core.autocrlf false
```