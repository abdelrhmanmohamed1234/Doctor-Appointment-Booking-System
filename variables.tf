############################################
# Project Variables
############################################
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use for authentication"
  type        = string
  default     = "default"
}

variable "project_name" {
  description = "The name of the project (used for naming resources)"
  type        = string
  default     = "doctor-booking"
}

variable "lambda_handler" {
  description = "Handler for the Lambda function"
  type        = string
  default     = "lambda_function.lambda_handler"
}

variable "lambda_runtime" {
  description = "Runtime environment for the Lambda function"
  type        = string
  default     = "python3.9"
}

variable "notification_email" {
  description = "Email address to receive booking notifications"
  type        = string
  default     = "abd0001102002@gmail.com"
}

