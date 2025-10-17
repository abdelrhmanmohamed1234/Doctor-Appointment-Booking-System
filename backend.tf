# Terraform backend configuration.
# NOTE: The S3 bucket and DynamoDB table used here must exist prior to running `terraform init`
# because Terraform will attempt to connect to them at init-time. See deployment steps below.
terraform {
  backend "s3" {}
}


