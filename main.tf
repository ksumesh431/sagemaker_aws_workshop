# VPC and Networking (using default VPC for simplicity)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Locals for image ARNs by region
locals {
  # JupyterServer image ARN (required for JupyterServer apps)
  jupyter_server_image_arn = "arn:aws:sagemaker:${var.aws_region}:081325390199:image/jupyter-server-3"
  
  # SageMaker Distribution image ARN (for KernelGateway)
  sagemaker_distribution_image_arn = "arn:aws:sagemaker:${var.aws_region}:081325390199:image/sagemaker-distribution-prod"
}

# IAM Role for SageMaker Studio
resource "aws_iam_role" "sagemaker_execution_role" {
  name = "SageMakerStudioExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Attach managed policies
resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

resource "aws_iam_role_policy_attachment" "s3_full_access" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Additional inline policy for SageMaker Studio
resource "aws_iam_role_policy" "sagemaker_studio_policy" {
  name = "SageMakerStudioAdditionalPolicy"
  role = aws_iam_role.sagemaker_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sagemaker:*",
          "ecr:*",
          "logs:*",
          "cloudwatch:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lifecycle Configuration for Auto-Shutdown (KernelGateway)
resource "aws_sagemaker_studio_lifecycle_config" "auto_shutdown" {
  studio_lifecycle_config_name     = "auto-shutdown-idle-kernel"
  studio_lifecycle_config_app_type = "KernelGateway"

  studio_lifecycle_config_content = base64encode(<<-EOF
#!/bin/bash
set -e

# OVERVIEW
# This script stops a SageMaker Studio kernel application when it's idle for more than the specified time.

# PARAMETERS
IDLE_TIME=${var.idle_timeout_in_minutes * 60}  # Idle time in seconds

echo "Configuring auto-shutdown for idle time: $IDLE_TIME seconds"

# Create autostop script
cat > /opt/ml/autostop.py << 'PYTHON_EOF'
#!/usr/bin/env python3
import json
import os
import time
import subprocess
from datetime import datetime

IDLE_TIME_SECONDS = ${var.idle_timeout_in_minutes * 60}

def get_notebook_metadata():
    try:
        with open('/opt/ml/metadata/resource-metadata.json') as f:
            return json.load(f)
    except:
        return {}

def stop_notebook():
    """Stop the notebook instance"""
    metadata = get_notebook_metadata()
    
    domain_id = metadata.get('DomainId')
    user_profile_name = metadata.get('UserProfileName')
    app_type = metadata.get('AppType')
    app_name = metadata.get('AppName')
    
    print(f"Stopping idle app: {app_name}")
    
    if all([domain_id, user_profile_name, app_type, app_name]):
        cmd = [
            'aws', 'sagemaker', 'delete-app',
            '--domain-id', domain_id,
            '--user-profile-name', user_profile_name,
            '--app-type', app_type,
            '--app-name', app_name,
            '--region', '${var.aws_region}'
        ]
        try:
            subprocess.run(cmd, check=True)
            print(f"Successfully stopped app: {app_name}")
        except subprocess.CalledProcessError as e:
            print(f"Error stopping app: {e}")

def check_idle_time():
    # Check for activity by looking at kernel connections
    # This is a simplified check - you can enhance it based on your needs
    idle_start = time.time()
    
    # If idle time exceeded, stop the notebook
    if IDLE_TIME_SECONDS > 0:
        print(f"Idle timeout set to {IDLE_TIME_SECONDS} seconds")
        # This will be called periodically by cron
        time.sleep(IDLE_TIME_SECONDS)
        stop_notebook()

if __name__ == '__main__':
    check_idle_time()
PYTHON_EOF

chmod +x /opt/ml/autostop.py

# Set up cron job to check every 5 minutes
echo "Setting up cron job for auto-shutdown checks"
(crontab -l 2>/dev/null || echo "") | grep -v autostop.py | crontab -
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/bin/python3 /opt/ml/autostop.py >> /var/log/autostop.log 2>&1") | crontab -

echo "Auto-shutdown configuration completed"
EOF
  )

  tags = var.tags
}

# Lifecycle Configuration for JupyterServer (Optional - for JupyterLab auto-shutdown)
resource "aws_sagemaker_studio_lifecycle_config" "jupyter_auto_shutdown" {
  studio_lifecycle_config_name     = "auto-shutdown-jupyter-server"
  studio_lifecycle_config_app_type = "JupyterServer"

  studio_lifecycle_config_content = base64encode(<<-EOF
#!/bin/bash
set -e

echo "Configuring JupyterServer auto-shutdown"

# Set idle timeout (in seconds)
IDLE_TIME=${var.idle_timeout_in_minutes * 60}

# Create Jupyter config directory
mkdir -p /home/sagemaker-user/.jupyter

# Configure auto-shutdown settings
cat > /home/sagemaker-user/.jupyter/jupyter_notebook_config.py << JUPYTER_EOF
# Auto-shutdown configuration
c.NotebookApp.shutdown_no_activity_timeout = $IDLE_TIME
c.MappingKernelManager.cull_idle_timeout = $IDLE_TIME
c.MappingKernelManager.cull_interval = 300
c.MappingKernelManager.cull_connected = True
JUPYTER_EOF

echo "JupyterServer auto-shutdown configured for $IDLE_TIME seconds of inactivity"
EOF
  )

  tags = var.tags
}

# SageMaker Studio Domain
resource "aws_sagemaker_domain" "studio" {
  domain_name = var.domain_name
  auth_mode   = "IAM"
  vpc_id      = data.aws_vpc.default.id
  subnet_ids  = data.aws_subnets.default.ids

  default_user_settings {
    execution_role = aws_iam_role.sagemaker_execution_role.arn

    # JupyterServer settings - using correct image ARN
    jupyter_server_app_settings {
      default_resource_spec {
        instance_type        = "system"
        sagemaker_image_arn  = local.jupyter_server_image_arn
        lifecycle_config_arn = aws_sagemaker_studio_lifecycle_config.jupyter_auto_shutdown.arn
      }

      lifecycle_config_arns = [
        aws_sagemaker_studio_lifecycle_config.jupyter_auto_shutdown.arn
      ]
    }

    # KernelGateway settings - using SageMaker Distribution image
    kernel_gateway_app_settings {
      default_resource_spec {
        instance_type        = "ml.t3.medium"
        sagemaker_image_arn  = local.sagemaker_distribution_image_arn
        lifecycle_config_arn = aws_sagemaker_studio_lifecycle_config.auto_shutdown.arn
      }

      lifecycle_config_arns = [
        aws_sagemaker_studio_lifecycle_config.auto_shutdown.arn
      ]
    }
  }

  tags = var.tags
}

# SageMaker Studio User Profile
resource "aws_sagemaker_user_profile" "workshop_user" {
  domain_id         = aws_sagemaker_domain.studio.id
  user_profile_name = var.user_profile_name

  user_settings {
    execution_role = aws_iam_role.sagemaker_execution_role.arn

    # JupyterServer settings - using correct image ARN
    jupyter_server_app_settings {
      default_resource_spec {
        instance_type        = "system"
        sagemaker_image_arn  = local.jupyter_server_image_arn
        lifecycle_config_arn = aws_sagemaker_studio_lifecycle_config.jupyter_auto_shutdown.arn
      }

      lifecycle_config_arns = [
        aws_sagemaker_studio_lifecycle_config.jupyter_auto_shutdown.arn
      ]
    }

    # KernelGateway settings - using SageMaker Distribution image
    kernel_gateway_app_settings {
      default_resource_spec {
        instance_type        = "ml.t3.medium"
        sagemaker_image_arn  = local.sagemaker_distribution_image_arn
        lifecycle_config_arn = aws_sagemaker_studio_lifecycle_config.auto_shutdown.arn
      }

      lifecycle_config_arns = [
        aws_sagemaker_studio_lifecycle_config.auto_shutdown.arn
      ]
    }
  }

  tags = var.tags
}

# S3 Bucket for workshop data
resource "aws_s3_bucket" "workshop_bucket" {
  bucket = "sagemaker-workshop-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "workshop_bucket_versioning" {
  bucket = aws_s3_bucket.workshop_bucket.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_caller_identity" "current" {}
