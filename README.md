A solution that handles stripe webhooks by using AWS http API Gateway, SQS, SQS dead letter queue, and Lambda. It is the main way for https://github.com/nicktsan/movies_frontend_nextjs to fulfill orders. It will send events to https://github.com/nicktsan/movie-ownership-crud for processing movie ownership

Make sure to set up STRIPE_API_KEY environment variable
Console Command Example: export STRIPE_API_KEY="<api-key>"

Configure hashicorp vault: https://developer.hashicorp.com/vault/tutorials/hcp-vault-secrets-get-started/hcp-vault-secrets-install-cli
Make sure to setup and store the stripe api key secret and stripe webhook signing secret in hcp vaults
export HCP_CLIENT_ID=<copied-id>
export HCP_CLIENT_SECRET=<copied-secret>
Run vlt secrets list to review the existing secrets.
check HCP environment variables: printenv | grep HCP_

First, ensure you have the AWS_PROFILE environment variable set to your desired user.
Linux: export AWS_PROFILE=<your aws profile>
Windows command prompt for current CMD session: set AWS_PROFILE=<your aws profile>
or
export AWS_ACCESS_KEY_ID=<your aws access key>
export AWS_SECRET_ACCESS_KEY=<your aws secret access key>
check AWS environment variables: printenv | grep AWS_

Before using terraform commands to init, plan, and deploy, switch to the /lambda directory and run the following
yarn commands:

yarn build, yarn lint, yarn package

switch to new workspace:
terraform workspace new <workspace name>

If you want to force terraform to redeploy the API Gateway, you can manually change the "revision" variable in input.tfvars before running terraform init

Then run:
    terraform init

Then run: 
terraform plan -out out.tfplan
This will save the output of the plan to a file and create the workspace in your Terraform organization.
Alternatively, if you want to use an input file to avoid manually inputting values for database_name, database_master_username, vpc_id, and region, run:
terraform plan -var-file input.tfvars -out out.tfplan
where input.tfvars contains values for database_name, database_master_username, vpc_id, and region.

After planning is finished, create the aws infrastructure with
terraform apply out.tfplan

If resources have been manually changed, follow the steps below to sync state file with manual changes:
1. Run the following command to sync terraform statefile when resources are manually changed.
terraform plan -refresh-only -var-file input.tfvars
2. After plan, run the following apply command:
terraform apply -refresh-only -var-file='input.tfvars'

If you encounter Error: Error acquiring the state lock, use the command below to forcefully unlock the state file. Only do this
if you know there is no other process manipulating the terraform.tfstate file:
terraform force-unlock <ID>
ID should be mentioned somewhere in the error message

to destroy:
terraform destroy -var-file input.tfvars