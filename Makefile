.PHONY: help setup init plan apply destroy clean logs

ENVIRONMENT ?= dev
REGION ?= us-east-1
CLUSTER_NAME ?= eks-strimzi-$(ENVIRONMENT)

help:
	@echo "AWS EKS-Strimzi Project - Available Commands"
	@echo ""
	@echo "Infrastructure:"
	@echo "  make setup              - Setup project and install dependencies"
	@echo "  make init               - Initialize Terraform"
	@echo "  make plan               - Plan infrastructure changes"
	@echo "  make apply              - Apply infrastructure changes"
	@echo "  make destroy            - Destroy infrastructure"
	@echo ""
	@echo "Kubernetes:"
	@echo "  make k8s-status         - Check Kafka cluster status"
	@echo "  make k8s-pods           - List all Kafka pods"
	@echo "  make k8s-topics         - List Kafka topics"
	@echo "  make k8s-create-topic   - Create example topic (TOPIC_NAME=my-topic)"
	@echo ""
	@echo "Monitoring:"
	@echo "  make grafana            - Port forward to Grafana"
	@echo "  make prometheus         - Port forward to Prometheus"
	@echo ""
	@echo "Utilities:"
	@echo "  make logs               - Tail Kafka operator logs"
	@echo "  make kubeconfig         - Update kubeconfig"
	@echo "  make validate           - Validate Terraform"
	@echo "  make fmt                - Format Terraform files"
	@echo "  make clean              - Clean temporary files"
	@echo ""
	@echo "Usage: make [command] ENVIRONMENT=dev"
	@echo ""

setup:
	@echo "Setting up project..."
	@bash setup.sh

init:
	@echo "Initializing Terraform..."
	@cd terraform && terraform init -upgrade

validate:
	@echo "Validating Terraform..."
	@cd terraform && terraform validate

fmt:
	@echo "Formatting Terraform files..."
	@cd terraform && terraform fmt -recursive

plan:
	@echo "Planning infrastructure for $(ENVIRONMENT) environment..."
	@cd terraform && terraform plan -var-file="environments/$(ENVIRONMENT)/terraform.tfvars" -out="$(ENVIRONMENT).tfplan"

apply:
	@echo "Applying infrastructure changes for $(ENVIRONMENT) environment..."
	@cd terraform && terraform apply "$(ENVIRONMENT).tfplan"
	@make kubeconfig

destroy:
	@echo "WARNING: This will destroy all resources in $(ENVIRONMENT) environment!"
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd terraform && terraform destroy -var-file="environments/$(ENVIRONMENT)/terraform.tfvars"; \
	fi

kubeconfig:
	@echo "Updating kubeconfig..."
	@aws eks update-kubeconfig --region $(REGION) --name $(CLUSTER_NAME)

k8s-status:
	@./scripts/shell/k8s-manage.sh status kafka

k8s-pods:
	@./scripts/shell/k8s-manage.sh pods kafka

k8s-topics:
	@./scripts/shell/k8s-manage.sh topics kafka

k8s-create-topic:
	@./scripts/shell/k8s-manage.sh topic-create $(TOPIC_NAME) 3 1 kafka

logs:
	@kubectl logs -f deployment/strimzi-cluster-operator -n kafka

grafana:
	@echo "Forwarding to Grafana on http://localhost:3000"
	@kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

prometheus:
	@echo "Forwarding to Prometheus on http://localhost:9090"
	@kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

clean:
	@echo "Cleaning temporary files..."
	@cd terraform && rm -f *.tfplan *.tfstate.backup
	@find . -name ".DS_Store" -delete
	@find . -name "*.tmp" -delete
	@echo "Cleanup complete!"
