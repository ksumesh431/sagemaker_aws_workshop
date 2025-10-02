
# Outputs
output "sagemaker_domain_id" {
  description = "SageMaker Studio Domain ID"
  value       = aws_sagemaker_domain.studio.id
}

output "sagemaker_domain_url" {
  description = "SageMaker Studio Domain URL"
  value       = aws_sagemaker_domain.studio.url
}

output "user_profile_name" {
  description = "SageMaker Studio User Profile Name"
  value       = aws_sagemaker_user_profile.workshop_user.user_profile_name
}

output "execution_role_arn" {
  description = "SageMaker Execution Role ARN"
  value       = aws_iam_role.sagemaker_execution_role.arn
}

output "s3_bucket_name" {
  description = "S3 Bucket for workshop data"
  value       = aws_s3_bucket.workshop_bucket.id
}

output "idle_timeout_minutes" {
  description = "Auto-shutdown idle timeout in minutes"
  value       = var.idle_timeout_in_minutes
}

output "jupyter_server_image" {
  description = "JupyterServer Image ARN"
  value       = local.jupyter_server_image_arn
}

output "kernel_gateway_image" {
  description = "KernelGateway (SageMaker Distribution) Image ARN"
  value       = local.sagemaker_distribution_image_arn
}

output "studio_access_instructions" {
  description = "Instructions to access SageMaker Studio"
  value       = <<-EOT
    1. Go to AWS Console > SageMaker > Domains > ${var.domain_name}
    2. Select User profiles > ${var.user_profile_name}
    3. Click 'Launch' > 'Studio'
    4. Auto-shutdown is configured for ${var.idle_timeout_in_minutes} minutes of inactivity
    5. You can manually stop apps from the Studio UI or AWS Console to save costs
  EOT
}

output "cost_saving_tips" {
  description = "Cost saving tips"
  value       = <<-EOT
    💰 Cost Saving Tips:
    - Auto-shutdown is enabled (${var.idle_timeout_in_minutes} min idle timeout)
    - Kernel Gateway apps auto-stop after inactivity
    - You can manually stop apps: SageMaker Console > Domains > Apps > Delete
    - Or via CLI: aws sagemaker delete-app --domain-id ${aws_sagemaker_domain.studio.id} --user-profile-name ${var.user_profile_name} --app-type KernelGateway --app-name <app-name>
    - You only pay for running compute (ml.t3.medium = ~$0.05/hour)
  EOT
}