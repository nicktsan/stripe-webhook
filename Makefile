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
	terraform destroy -var-file input.tfvars -auto-approve

all: init sync validate plan apply
# all: init sync destroy
