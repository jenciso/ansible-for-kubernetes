#!/bin/bash
#
# Tests for cluster-aws-eks playbook.
set -e

cd cluster-aws-eks

# Install AWS CLI.
pip3 install awscli yamllint cfn-lint ansible-lint ansible openshift

# Export AWS vars.
export AWS_DEFAULT_REGION=us-east-1

# Validate Cloudformation templates.
echo "Validating CloudFormation templates..."
for template in cloudformation/*.yml; do
  yamllint --strict $template
  cfn-lint --include-checks I --template $template
  # validate-template requires valid AWS Credentials :(
  # aws cloudformation validate-template --template-body file://$template --region us-east-1
done

# Check ansible playbooks for correctness.
playbooks="main.yml deploy.yml delete.yml"
echo "Checking playbook syntax..."
ansible-playbook -i inventory $playbooks --syntax-check
echo "Linting playbooks with ansible-lint..."
ansible-lint $playbooks

# Prepare a Kind cluster.
echo "Preparing Kind cluster..."
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
curl -Lo kind https://github.com/kubernetes-sigs/kind/releases/download/v0.6.1/kind-linux-amd64
chmod +x kind
sudo mv kind /usr/local/bin/
export KUBECONFIG="${HOME}/.kube/kind-config-test"
kind create cluster --name=test --quiet

# Test Wordpress manifests in Kind cluster.
ansible-playbook -i inventory deploy.yml \
  -e "k8s_kubeconfig=$KUBECONFIG" \
  -e "aws_environment=false" \
  -e "k8s_no_log=false"

# Verify Wordpress service is present.
kubectl get service wordpress
