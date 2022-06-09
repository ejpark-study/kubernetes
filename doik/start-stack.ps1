
aws cloudformation deploy --template-file cloudneta-k8s-3.yaml --stack-name doik --parameter-overrides KeyName=default SgIngressCidr=$(curl -s ipinfo.io/ip)/32

aws cloudformation describe-stacks
