$node_ip=$(aws cloudformation describe-stacks | Select-String MasterNodeIP).Line.split('IP').trim()[-1]
ssh -i default.pem ubuntu@$node_ip