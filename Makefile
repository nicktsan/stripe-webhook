init:
	terraform init

validate:
	terraform fmt -recursive
	terraform validate

plan:
	terraform plan -var-file input.tfvars -out out.tfplan

apply:
	terraform apply out.tfplan

sync:
	terraform apply -refresh-only -var-file='input.tfvars' --auto-approve

destroy:
	terraform destroy -var-file input.tfvars

all: init validate plan apply sync
