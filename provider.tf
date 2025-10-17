# Configure the AWS provider. Region and profile come from variables.
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

