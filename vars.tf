# Variables
variable "aws_region" {
  description = "AWS region for the workshop"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = contains(["us-east-1", "us-west-2"], var.aws_region)
    error_message = "Region must be us-east-1 or us-west-2 as recommended."
  }
}

variable "domain_name" {
  description = "Name for the SageMaker Studio domain"
  type        = string
  default     = "sagemaker-workshop-domain"
}

variable "user_profile_name" {
  description = "Name for the SageMaker Studio user profile"
  type        = string
  default     = "workshop-user"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "Workshop"
    ManagedBy   = "Terraform"
  }
}

variable "idle_timeout_in_minutes" {
  description = "Idle timeout in minutes before auto-shutdown (0 to disable)"
  type        = number
  default     = 30
}

variable "kernel_gateway_instance_type" {
  description = "Instance type for the Kernel Gateway"
  type        = string
  default     = "ml.t3.medium"
}