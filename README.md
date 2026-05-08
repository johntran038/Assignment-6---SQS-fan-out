# Assignment-6---SQS-fan-out

## Prerequisites
- Terraform
  - https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli
- AWS configured (`aws configure`)

## Setup
```bash
pip install pillow -t temp_folder
cd temp_folder && zip -r ../lambda_thumbnail.zip . && cd ..
```

## Terraform

### Initialize Terraform
- `terraform init`

### Apply Deployment
```bash
terraform apply
```

- Terraform will prompt for confirmation. Type: `yes`


## Clean Up (Deleting the Terraform)
```bash
terraform destroy
```

- Terraform will prompt for confirmation. Type: `yes`
