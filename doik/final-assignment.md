# Database Operator In Kubernetes study (DOIK) 스터디 종료 과제

이전 직장에서 크롤링 결과를 Elasticsearch 에 저장하고 크롤링 상태를 Kibana 에서 조회했다. 물리서버 3대에 docker 로 master, ingest, data 구분없이 실행해서 사용했다. 앞에 reverse proxy로 부하 분산정도 세팅해서 무리없이 5년이상 운영하였다. 이번에 Kubernetes Database Operator 한다고 했을때 내심 Elasticsearch Operator 가 가장 궁금했었다. 어떻게 장애 테스트하고, 어떻게 복구되는지가 사실 궁금했었다. 서비스에 사용하고 있어서 버전 업그레이드도 5년 동안 2번 해본게 다라서 내심 궁금했었다. 생각해 보면 물리서버에서 빅데이터가 저장된 서버를 구축하는 것과 쿠버네티스에서 시스템을 구성하는 것은 다를 것 같다. 이전에는 openstack 으로 VM 을 생성해서 사용했었는데, 이제는 openshift 로 이 방식을 더 이상 사용할 수 없다. 

사실 몇번 쿠버네티스에 올리려고 했었는데 ceph 에 올렸다가 몇번 깨지는 것을 보고 완전히 포기했었다. 이번 스터디에서 배운 장애를 발생하는 것과 복구과정을 확인하는 방법을 중심으로 해보고자 한다. 

# Docker Style


## [docker] Elasticsearch + Kibana

* [KANS Final](https://github.com/ejpark78/kans/blob/main/intermediate-assignment.md)

0) hosts 파일 생성

```bash
cat <<EOF | tee hosts
elk-n1
elk-n2
elk-n3
EOF
```

2) docker image build

1-1) 노드간 ssl 통신을 위한 elastic-certificates 생성

> 언제부터인가 노드간 통신에 TLS 가 사용되었다. 해줘야 한다.

* [elasticsearch tls](https://www.elastic.co/guide/en/elasticsearch/reference/current/configuring-tls.html)
* [kibana tls](https://www.elastic.co/guide/en/kibana/master/configuring-tls.html)

```bash
docker run \
  -it --rm \
  --volume "$(pwd)/certs:/mnt:rw" \
  docker.elastic.co/elasticsearch/elasticsearch:7.17.0 \
    bin/elasticsearch-certutil ca \
    && bin/elasticsearch-certutil cert --ca elastic-stack-ca.p12 \
    && openssl pkcs12 -in elastic-certificates.p12 -cacerts -nokeys -out elasticsearch-ca.pem \
    && bin/elasticsearch-certutil ca --pem \
    && mv *.p12 *.pem /mnt/
```

2) elasticsearch

형태소 분석기와 같은 plugin 을 이미지에 설치해 준다.

* https://logz.io/blog/language-analyzers-tokenizers-not-built-elasticsearch-where-find-them/
 
```bash
cat <<EOF | tee Dockerfile
FROM docker.elastic.co/elasticsearch/elasticsearch:7.17.0

RUN echo "analysis plugins: BASE_IMAGE " \
    && bin/elasticsearch-plugin install analysis-nori \
    && bin/elasticsearch-plugin install analysis-kuromoji \
    && bin/elasticsearch-plugin install analysis-smartcn \
    && bin/elasticsearch-plugin install analysis-icu

RUN echo "repository plugins" \
   && bin/elasticsearch-plugin install --batch repository-hdfs \
   && bin/elasticsearch-plugin install --batch repository-s3

ADD certs/* /usr/share/elasticsearch/config/certs/

RUN chown -R elasticsearch /usr/share/elasticsearch/config/certs/
EOF

docker build -t mydomain.com:5000/elk/elasticsearch:7.17.0 .
```

3) kibana

```bash
cat <<EOF | tee Dockerfile
FROM docker.elastic.co/kibana/kibana:7.17.0

ADD certs/* /usr/share/kibana/config/elasticsearchcerts/

USER root

RUN chown -R kibana /usr/share/kibana/config/elasticsearchcerts/

USER kibana
EOF

docker build -t mydomain.com:5000/elk/kibana:7.17.0 .
```

4) install elasticsearch

4-1) vm.max_map_count 설정

```bash
BATCH=set_vm_max_map_count.sh

cat <<EOF | tee ${BATCH}
sudo swapoff -a
echo vm.max_map_count=262144 | sudo tee -a /etc/sysctl.conf
sudo sysctl --system
EOF

cat nodes | xargs -I{} scp ${BATCH} {}: 
cat nodes | xargs -I{} ssh {} "bash ${BATCH}" 
```

4-2) docker image push

```bash
docker save mydomain.com:5000/elk/elasticsearch:7.17.0 | gzip - > elasticsearch-7.17.0.tar.gz

cat nodes | xargs -I{} scp elasticsearch-7.17.0.tar.gz {}:
cat nodes | xargs -I{} ssh {} "docker load < elasticsearch-7.17.0.tar.gz"
```

4-3) data path permission fix

```bash
cat nodes | xargs -I{} ssh {} "sudo mkdir -p /data/elasticsearch"
cat nodes | xargs -I{} ssh {} "sudo chown -R 1000:1000 /data/elasticsearch"
```

4-4) elasticsearch docker command

```bash
BATCH=start-elasticsearch.sh

cat <<EOF | tee ${BATCH}
#!/usr/bin/env bash

NODE_NAME="\$1"

CLS_NAME="dev"
CONTAINER_NAME="elasticsearch"
IMAGE="mydomain.com:5000/elk/elasticsearch:7.17.0"
ELASTIC_USERNAME="elastic"
ELASTIC_PASSWORD="mypassword"
ES_JAVA_OPTS="-Xms8g -Xmx8g"
SEED_HOSTS="elk-n1,elk-n2,elk-n3"
WHITELIST="mydomain.com:9200"
DATA_HOME="/data/elasticsearch"

docker run \\
  --detach --restart=unless-stopped \\
  --privileged \\
  --network host \\
  --ulimit "memlock=-1:-1" \\
  --name "\${CONTAINER_NAME}" \\
  --hostname "\${NODE_NAME}" \\
  --env "HOSTNAME=\${NODE_NAME}" \\
  --env "ELASTIC_USERNAME=\${ELASTIC_USERNAME}" \\
  --env "ELASTIC_PASSWORD=\${ELASTIC_PASSWORD}" \\
  --env "node.name=\${NODE_NAME}" \\
  --env "ES_JAVA_OPTS=\${ES_JAVA_OPTS}" \\
  --env "discovery.seed_hosts=\${SEED_HOSTS}" \\
  --env "discovery.zen.minimum_master_nodes=3" \\
  --env "cluster.name=\${CLS_NAME}" \\
  --env "cluster.publish.timeout=90s" \\
  --env "cluster.initial_master_nodes=\${SEED_HOSTS}" \\
  --env "transport.tcp.compress=true" \\
  --env "network.host=0.0.0.0" \\
  --env "node.master=true" \\
  --env "node.ingest=true" \\
  --env "node.data=true" \\
  --env "node.ml=false" \\
  --env "node.remote_cluster_client=true" \\
  --env "xpack.security.enabled=true" \\
  --env "xpack.security.http.ssl.enabled=true" \\
  --env "xpack.security.http.ssl.keystore.path=/usr/share/elasticsearch/config/certs/elastic-certificates.p12" \\
  --env "xpack.security.http.ssl.truststore.path=/usr/share/elasticsearch/config/certs/elastic-certificates.p12" \\
  --env "xpack.security.transport.ssl.enabled=true" \\
  --env "xpack.security.transport.ssl.verification_mode=certificate" \\
  --env "xpack.security.transport.ssl.keystore.path=/usr/share/elasticsearch/config/certs/elastic-certificates.p12" \\
  --env "xpack.security.transport.ssl.truststore.path=/usr/share/elasticsearch/config/certs/elastic-certificates.p12" \\
  --env "reindex.remote.whitelist=\${WHITELIST}" \\
  --volume "\${DATA_HOME}/snapshot:/snapshot:rw" \\
  --volume "\${DATA_HOME}/data:/usr/share/elasticsearch/data:rw" \\
  \${IMAGE}
EOF

cat nodes | xargs -I{} scp ${BATCH} {}:
cat nodes | xargs -I{} echo "ssh {} \"bash ${BATCH} {} ; docker ps\""
```

4-5) api test

```bash
❯ curl -k -u elastic:mypassword https://mydomain.com:9200/
```

5) kibana install

5-1) docker image pull & push

```bash
docker save mydomain.com:5000/elk/kibana:7.17.0 | gzip - > kibana-7.17.0.tar.gz

cat nodes | grep kibana | xargs -I{} scp kibana-7.17.0.tar.gz {}:
cat nodes | grep kibana | xargs -I{} ssh {} "docker load < kibana-7.17.0.tar.gz"
```

5-2) kibana 암호 설정

```bash
curl -k -u elastic:mypassword -H 'Content-Type: application/json' -d '{"password": "mypassword#"}' \
  https://mydomain.com:9200/_security/user/kibana_system/_password 
```

5-3) start kibana

```bash
BATCH=start-kibana.sh

cat <<EOF | tee ${BATCH}
#!/usr/bin/env bash

CONTAINER_NAME="kibana"
ELASTICSEARCH_USERNAME="kibana_system"
ELASTICSEARCH_PASSWORD="mypassword"
ELASTICSEARCH_HOSTS="https://mydomain.com:9200"
IMAGE="mydomain.com:5000/elk/kibana:7.17.0"

docker run \\
  --detach --restart=unless-stopped \\
  --name "\${CONTAINER_NAME}" \\
  --hostname "\${CONTAINER_NAME}" \\
  --network host \\
  --add-host "mydomain.com:172.0.0.10" \\
  --env "SERVER_HOST=0.0.0.0" \\
  --env "ELASTICSEARCH_HOSTS=\${ELASTICSEARCH_HOSTS}" \\
  --env "ELASTICSEARCH_USERNAME=\${ELASTICSEARCH_USERNAME}" \\
  --env "ELASTICSEARCH_PASSWORD=\${ELASTICSEARCH_PASSWORD}" \\
  --env "MONITORING_ENABLED=true" \\
  --env "NODE_OPTIONS=--max-old-space-size=1800" \\
  --env "ELASTICSEARCH_SSL_ENABLED=true" \\
  --env "ELASTICSEARCH_SSL_VERIFICATIONMODE=certificate" \\
  --env "ELASTICSEARCH_SSL_KEYSTORE_PATH=/usr/share/kibana/config/elasticsearchcerts/elastic-certificates.p12" \\
  --env "ELASTICSEARCH_SSL_KEYSTORE_PASSWORD=\"\"" \\
  --env "SERVER_SSL_ENABLED=true" \\
  --env "SERVER_SSL_KEYSTORE_PATH=/usr/share/kibana/config/elasticsearchcerts/elastic-certificates.p12" \\
  --env "SERVER_SSL_KEYSTORE_PASSWORD=\"\"" \\
  \${IMAGE}
EOF

cat nodes | grep kibana | xargs -I{} scp ${BATCH} {}:
```

6) haproxy reverse proxy & loadbalancer

```shell
❯ cat haproxy.cfg
global
    log 127.0.0.1 local2

    maxconn 5000
    tune.ssl.default-dh-param 2048

    spread-checks 5
    max-spread-checks 15000
    tune.ssl.default-dh-param 2048

    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA256:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:!aNULL:!MD5:!DSS
    ssl-default-bind-options no-sslv3 no-tlsv10 no-tls-tickets
    ssl-default-server-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA256:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:!aNULL:!MD5:!DSS
    ssl-default-server-options no-sslv3 no-tlsv10 no-tls-tickets

defaults
    log     global
    mode    tcp

    retries                   3
    backlog               10000
    maxconn               10000

    timeout connect       6000s
    timeout client        6000s
    timeout server        6000s
    timeout tunnel        6000s
    timeout http-keep-alive 60s
    timeout http-request    30s
    timeout queue         6000s
    timeout tarpit        6000s

    option            dontlognull
    option            http-server-close
    option            redispatch

listen stats
    bind *:9000
    mode http
    stats enable
    stats hide-version
    stats realm HAproxy-Statistics
    stats uri /stats
    monitor-uri /_health_check

# elasticsearch
frontend elasticsearch
    bind *:9200
    mode tcp
    option tcplog
    default_backend elasticsearch

backend elasticsearch
    mode tcp
    option tcp-check
    balance roundrobin
    server elk-n1 elk-n1:9200 check inter 30s
    server elk-n2 elk-n2:9200 check inter 30s
    server elk-n3 elk-n3:9200 check inter 30s

# kibana
frontend kibana
    bind *:5601
    mode tcp
    option tcplog
    default_backend kibana

backend kibana
    mode tcp
    option tcp-check
    server kibana kibana:5601 check inter 30s

```

여기서, loadbalancer 설정은 이부분이다. 

```yaml
backend elasticsearch
    mode tcp
    option tcp-check
    balance roundrobin
    server elk-n1 elk-n1:9200 check inter 30s
    server elk-n2 elk-n2:9200 check inter 30s
    server elk-n3 elk-n3:9200 check inter 30s
```

loadbalancer dockrefile 로 빌드해서 사용할 수 있다.

```shell
❯ cat Dockerfile
FROM haproxy:latest

ADD haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
```

haproxy.cfg 를 설정한 다음에 haproxy docker 로 실행한다.

```shell
docker run \
    -d --restart=unless-stopped \
    --name proxy \
    --network=host \
    -v haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg \
    haproxy:latest
```

# Helm Style

TODO

# Elasticsearch Operator

* [elastic-cloud-eck](https://operatorhub.io/operator/elastic-cloud-eck)

* Capability Level
![](https://operatorhub.io/static/images/level-3.svg)

```text
Elasticsearch (ECK) Operator

Elastic Cloud on Kubernetes (ECK) is the official operator by Elastic for automating the deployment, provisioning, management, and orchestration of Elasticsearch, Kibana, APM Server, Beats, Enterprise Search, Elastic Agent and Elastic Maps Server on Kubernetes.

Current features:

    Elasticsearch, Kibana, APM Server, Enterprise Search, Beats, Elastic Agent and Elastic Maps Server deployments
    TLS Certificates management
    Safe Elasticsearch cluster configuration and topology changes
    Persistent volumes usage
    Custom node configuration and attributes
    Secure settings keystore updates

Supported versions:

    Kubernetes 1.19-1.23
    OpenShift 4.6-4.10
    Google Kubernetes Engine (GKE), Azure Kubernetes Service (AKS), and Amazon Elastic Kubernetes Service (EKS)
    Elasticsearch, Kibana, APM Server: 6.8+, 7.1+, 8+
    Enterprise Search: 7.7+, 8+
    Beats: 7.0+, 8+
    Elastic Agent: 7.10+, 8+
    Elastic Maps Server: 7.11+, 8+
```
Supported versions 은 operatorhub 와 github 가 좀 다르다. 

* [cloud-on-k8s](https://github.com/elastic/cloud-on-k8s)

```text
Supported versions:

    Kubernetes 1.20-1.24
    OpenShift 4.6-4.10
    Elasticsearch, Kibana, APM Server: 6.8+, 7.1+, 8+
    Enterprise Search: 7.7+, 8+
    Beats: 7.0+, 8+
    Elastic Agent: 7.10+ (standalone), 7.14+, 8+ (Fleet)
    Elastic Maps Server: 7.11+, 8+

```

## Quickstart

* [Quickstart](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-quickstart.html)

* install operator

```shell
# 1) Install custom resource definitions:
kubectl create -f https://download.elastic.co/downloads/eck/2.2.0/crds.yaml

# 2) Install the operator with its RBAC rules:
kubectl apply -f https://download.elastic.co/downloads/eck/2.2.0/operator.yaml

# 3) Monitor the operator logs:
kubectl -n elastic-system logs -f statefulset.apps/elastic-operator
```

* Elasticsearch

```shell
cat <<EOF | kubectl apply -f -
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: quickstart
spec:
  version: 8.2.3
  nodeSets:
  - name: default
    count: 1
    config:
      node.store.allow_mmap: false
EOF

kubectl get elasticsearch

kubectl get pods --selector='elasticsearch.k8s.elastic.co/cluster-name=quickstart'

kubectl logs -f quickstart-es-default-0

# get service information
kubectl get service quickstart-es-http

# Get the credentials.
# A default user named elastic is automatically created with the password stored in a Kubernetes secret:

PASSWORD=$(kubectl get secret quickstart-es-elastic-user -o go-template='{{.data.elastic | base64decode}}')

# Request the Elasticsearch endpoint.

# From inside the Kubernetes cluster:

curl -u "elastic:$PASSWORD" -k "https://quickstart-es-http:9200"

# From your local workstation, use the following command in a separate terminal:

kubectl port-forward service/quickstart-es-http 9200

# Then request localhost:

curl -u "elastic:$PASSWORD" -k "https://localhost:9200"
```

* Kibana

```shell
# Specify a Kibana instance and associate it with your Elasticsearch cluster:

cat <<EOF | kubectl apply -f -
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: quickstart
spec:
  version: 8.2.3
  count: 1
  elasticsearchRef:
    name: quickstart
EOF

# Monitor Kibana health and creation progress.
# Similar to Elasticsearch, you can retrieve details about Kibana instances:

kubectl get kibana

# And the associated Pods:

kubectl get pod --selector='kibana.k8s.elastic.co/name=quickstart'

# Access Kibana.
# A ClusterIP Service is automatically created for Kibana:

kubectl get service quickstart-kb-http

# Use kubectl port-forward to access Kibana from your local workstation:

kubectl port-forward service/quickstart-kb-http 5601

# Login as the elastic user. The password can be obtained with the following command:

kubectl get secret quickstart-es-elastic-user -o=jsonpath='{.data.elastic}' | base64 --decode; echo
```

# Insert Data

# Self Healing

# Conclusion
