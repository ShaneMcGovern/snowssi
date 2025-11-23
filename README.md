# SnowSSI (Snowflake Stage S3 Integration): AWS-Snowflake Event-Driven File Processing Pipeline

[![Terraform](https://img.shields.io/badge/Terraform-1.0+-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS Provider](https://img.shields.io/badge/AWS-6.21.0-FF9900?logo=amazon-aws&logoColor=white)](https://registry.terraform.io/providers/hashicorp/aws/6.21.0)
[![Snowflake Provider](https://img.shields.io/badge/Snowflake-2.10.1-29B5E8?logo=snowflake&logoColor=white)](https://registry.terraform.io/providers/Snowflake-Labs/snowflake/2.10.1)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

[![Trivy Security Scan](https://img.shields.io/badge/security-Trivy-blue?logo=aqua)](https://aquasecurity.github.io/trivy/)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://github.com/pre-commit/pre-commit)
[![Python](https://img.shields.io/badge/Python-3.12.7-3776AB?logo=python&logoColor=white)](https://www.python.org/)

This Terraform module deploys an automated, event-driven file processing pipeline from AWS S3 to Snowflake using directory tables, streams, and triggered tasks. Unlike Snowpipe auto-ingest which is limited to COPY INTO operations, this pattern enables flexible, custom processing logic for each file detected on the stage, making it ideal for scenarios requiring file transformations, validations, or orchestrated multi-stage processing workflows.

## Features

- **Event-Driven Architecture** - Automatically processes files upon S3 upload using Snowflake streams on directory tables and triggered tasks
- **Dual-Stage Processing** - Separates inbound and outbound S3 buckets with independent Snowflake external stages for clear data flow segregation
- **Complete IAM Security** - Implements Snowflake storage integration with AWS IAM roles, eliminating hardcoded credentials and following AWS security best practices
- **KMS Encryption** - Encrypts all S3 buckets at rest using AWS KMS with automatic key rotation enabled
- **Production-Ready Infrastructure** - Includes S3 versioning, public access blocks, and bucket ownership controls configured to enterprise security standards

## Installation

### Prerequisites

Ensure you have the following tools installed:

**Required:**

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- [Snowflake CLI](https://docs.snowflake.com/en/user-guide/snowsql) configured with account access

**Development Tools:**

- [Python 3.12.7+](https://www.python.org/downloads/)
- [uv](https://github.com/astral-sh/uv) - Fast Python package installer
- [Trivy](https://aquasecurity.github.io/trivy/) - Security scanner for IaC
- [pre-commit](https://pre-commit.com/) - Git hook framework

**Installation Commands:**

```bash
# Install Trivy (Windows via Chocolatey)
choco install trivy

# Install TFLint (Windows via Chocolatey)
choco install tflint

# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install pre-commit via uv
uv tool install pre-commit
```

### Provider Version Requirements

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.21.0"
    }
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "2.10.1"
    }
  }
}
```

## Quick Start

### Initial Setup

1. **Clone the repository:**

```bash
git clone <repository-url>
cd snowflake-stage-integration-s3
```

2. **Install development dependencies:**

```bash
# Install Python dependencies including pre-commit hooks
uv sync

# Install pre-commit hooks
uv run pre-commit install
```

3. **Configure credentials:**

Create a `terraform.tfvars` file from the example template:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your credentials:

```hcl
# AWS Configuration
region     = "us-east-1"
access_key = "your-aws-access-key"
secret_key = "your-aws-secret-key"

# Snowflake Configuration
organization_name = "your-org"
account_name      = "your-account"
user              = "your-snowflake-user"
password          = "your-snowflake-password"
role              = "ACCOUNTADMIN"
```

4. **Initialize and deploy:**

```bash
# Initialize Terraform
terraform init

# Review the execution plan
terraform plan -out=local.tfplan

# Apply the infrastructure
terraform apply local.tfplan
```

5. **Run pre-commit checks:**

```bash
# Run all pre-commit hooks on all files
uv run pre-commit run --all-files
```

### Basic Usage Example

The module creates a complete event-driven pipeline. When you upload a file to the inbound S3 bucket, the following occurs automatically:

1. Snowflake's directory table detects the new file
2. The stream captures the file metadata change
3. The task triggers via `SYSTEM$STREAM_HAS_DATA()` condition
4. Files are copied from the inbound stage to the outbound stage
5. The stream is consumed and resets

**Test the pipeline:**

```bash
# Upload a test file to the inbound bucket
aws s3 cp test-file.csv s3://inbound-bucket-<random-name>/

# Monitor task execution in Snowflake
snowsql -q "SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
            WHERE NAME = 'TASK_<random-name>'
            ORDER BY SCHEDULED_TIME DESC LIMIT 10;"

# Verify file was copied to outbound bucket
aws s3 ls s3://outbound-bucket-<random-name>/
```

## Architecture

### How It Works

This module implements an **event-driven file processing pipeline** using Snowflake's directory table pattern with streams and tasks:

**Component Details:**

1. **External Stages** - Two S3-backed external stages (inbound/outbound) with directory tables enabled to store file-level metadata
2. **Storage Integration** - Secure IAM role-based authentication between Snowflake and AWS S3, eliminating hardcoded credentials
3. **Stream on Directory Table** - Tracks file-level changes (inserts when files are added, deletes when files are removed) on the inbound stage
4. **Triggered Task** - Executes automatically when `SYSTEM$STREAM_HAS_DATA()` returns TRUE, copying files from inbound to outbound stage using the `COPY FILES` command
5. **IAM Roles & Policies** - Complete AWS IAM configuration with least-privilege S3 and KMS permissions for Snowflake access

### Pattern Comparison

| Pattern                                             | Best For                                                                                                                 | Limitations                                                     |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------- |
| **Directory Table + Streams + Tasks** (This Module) | Custom file processing, transformations, unstructured data, complex validation logic, orchestrated multi-stage workflows | Requires warehouse management, task scheduling overhead         |
| **Snowpipe Auto-Ingest**                            | Simple COPY INTO ingestion, minimal latency requirements, streaming micro-batches                                        | Limited to COPY INTO, no custom logic, serverless compute costs |
| **Scheduled COPY INTO**                             | Predictable batch loads, simple requirements, cost-controlled processing windows                                         | Fixed schedule, not event-driven, may miss files between runs   |

## Module Structure

This module follows HashiCorp's standard module structure:

```
.
├── main.tf                          # Root module configuration
├── variables.tf                     # Input variables
├── outputs.tf                       # Output values
├── providers.tf                     # Provider configurations
├── locals.tf                        # Local values
├── data.tf                          # Data sources
├── versions.tf                      # Terraform version constraints
├── catalog/
│   └── modules/
│       ├── aws/
│       │   └── s3/                  # S3 bucket submodule
│       │       ├── main.tf          # S3 with encryption, versioning, and public access blocks
│       │       ├── variables.tf
│       │       └── output.tf
│       └── snowflake/
│           └── stage/               # Snowflake stage submodule
│               ├── main.tf          # External stage with directory table enabled
│               ├── variables.tf
│               └── output.tf
├── .pre-commit-config.yaml          # Pre-commit hook configuration
├── pyproject.toml                   # Python project configuration
└── README.md                        # This file
```

## Security

### Security Scanning

This module uses **Trivy** for infrastructure security scanning. Trivy is the modern replacement for the deprecated tfsec tool and provides comprehensive security analysis for Terraform configurations.

**Run security scan:**

```bash
# Scan Terraform configurations
trivy config .

# Scan with specific severity levels
trivy config --severity CRITICAL,HIGH .
```

Pre-commit hooks automatically run security checks before each commit to ensure code quality and security compliance.

### Security Best Practices

This module implements the following security best practices:

- **IAM Role-Based Authentication** - Uses Snowflake storage integration with AWS IAM roles instead of long-lived access keys
- **KMS Encryption** - All S3 buckets use AWS KMS for encryption at rest with automatic key rotation enabled
- **Least Privilege Access** - IAM policies grant only required S3 and KMS permissions (ListBucket, GetObject, PutObject, Decrypt, GenerateDataKey)
- **Storage Allowed Locations** - Storage integration restricts access to specific S3 bucket paths using `storage_allowed_locations` parameter
- **S3 Public Access Blocks** - All S3 buckets have public access completely blocked (block_public_acls, block_public_policy, ignore_public_acls, restrict_public_buckets)
- **S3 Versioning** - Enabled on all buckets to protect against accidental deletions and provide audit trail
- **No Hardcoded Credentials** - All sensitive values use Terraform variables marked as `sensitive = true`

### IAM Role Trust Relationship

The module automatically configures the IAM role trust relationship for Snowflake:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "<snowflake_storage_integration_iam_user_arn>"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "<snowflake_storage_integration_external_id>"
        }
      }
    }
  ]
}
```

## Key Components

### AWS Resources

- **S3 Buckets** - Two buckets (inbound/outbound) with KMS encryption, versioning, and complete public access blocks
- **KMS Key** - Customer-managed key with automatic rotation for S3 bucket encryption
- **IAM Role** - Trust relationship configured for Snowflake's IAM user with external ID condition
- **IAM Policy** - Least-privilege permissions for S3 (ListBucket, GetObject, GetObjectVersion, PutObject, DeleteObject) and KMS (Decrypt, GenerateDataKey)

### Snowflake Resources

- **Storage Integration** - Stores generated IAM entity for S3 access with allowed location restrictions
- **Database & Schema** - Isolated namespace for pipeline objects
- **Warehouse** - Compute resource for task execution (size configurable via `warehouse_sizes` variable)
- **External Stages** - Two S3-backed stages with directory tables enabled and auto-refresh configured
- **Stream** - CDC stream on inbound stage directory table to track file additions/removals
- **Task** - Serverless execution triggered by `SYSTEM$STREAM_HAS_DATA()` condition, executes `COPY FILES` command

### Module Dependencies

The root module composes two reusable submodules:

1. **aws/s3 module** - Creates S3 bucket with encryption, versioning, public access blocks, and ownership controls
2. **snowflake/stage module** - Creates external stage with directory table enabled, auto-refresh, and 30-second IAM propagation delay

## Documentation

### Official Documentation

**Snowflake:**

- [Building Data Processing Pipelines Using Directory Tables](https://docs.snowflake.com/en/user-guide/data-load-dirtables-pipeline)
- [Directory Tables Overview](https://docs.snowflake.com/en/user-guide/data-load-dirtables)
- [CREATE STORAGE INTEGRATION](https://docs.snowflake.com/en/sql-reference/sql/create-storage-integration)
- [CREATE STREAM](https://docs.snowflake.com/en/sql-reference/sql/create-stream) (Directory Table Streams)
- [Triggered Tasks](https://docs.snowflake.com/en/user-guide/tasks-triggered)
- [SYSTEM$STREAM_HAS_DATA](https://docs.snowflake.com/en/sql-reference/functions/system_stream_has_data)
- [COPY FILES Command](https://docs.snowflake.com/en/sql-reference/sql/copy-files)
- [Configuring Storage Integration for Amazon S3](https://docs.snowflake.com/en/user-guide/data-load-s3-config-storage-integration)

**AWS:**

- [S3 Bucket Configuration](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html)
- [IAM Roles for Cross-Account Access](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-user.html)
- [KMS Key Management](https://docs.aws.amazon.com/kms/latest/developerguide/overview.html)

**Terraform:**

- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Snowflake Provider Documentation](https://registry.terraform.io/providers/Snowflake-Labs/snowflake/latest/docs)

### Additional Resources

- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [pre-commit-terraform Hooks](https://github.com/antonbabenko/pre-commit-terraform)
- [Trivy IaC Scanning](https://aquasecurity.github.io/trivy/latest/docs/scanner/misconfiguration/)

## Development

### Pre-commit Hooks

This project uses pre-commit hooks to ensure code quality and security:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    hooks:
      - id: ruff-check
        args: [--fix]
      - id: ruff-format

  - repo: https://github.com/antonbabenko/pre-commit-terraform
    hooks:
      - id: terraform_fmt
      # Optional: Uncomment to enable additional checks
      # - id: terraform_tflint
      # - id: terraform_trivy

  - repo: https://github.com/adrienverge/yamllint.git
    hooks:
      - id: yamllint
        args: ["--no-warnings"]
```

**Enable pre-commit hooks:**

```bash
uv run pre-commit install
uv run pre-commit run --all-files
```

### Local Development Workflow

1. Make changes to Terraform configuration
2. Run pre-commit checks: `uv run pre-commit run --all-files`
3. Validate configuration: `terraform validate`
4. Format code: `terraform fmt -recursive`
5. Run security scan: `trivy config .`
6. Plan changes: `terraform plan -out=local.tfplan`
7. Review plan output carefully
8. Apply changes: `terraform apply local.tfplan`

### Testing

```bash
# Validate Terraform syntax
terraform validate

# Check formatting
terraform fmt -check -recursive

# Security scan with Trivy
trivy config --severity HIGH,CRITICAL .

# Run all pre-commit hooks
uv run pre-commit run --all-files
```

## Customization

### Configuring Processing Logic

The default task uses `COPY FILES` to move files between stages. To implement custom processing logic, modify the `sql_statement` in the `snowflake_task` resource:

```hcl
resource "snowflake_task" "task" {
  # ... other configuration ...

  sql_statement = <<-SQL
    -- Custom processing logic
    COPY INTO my_table
    FROM @inbound_stage
    FILE_FORMAT = (TYPE = 'CSV' FIELD_DELIMITER = ',')
    PATTERN = '.*[.]csv'
    ON_ERROR = 'CONTINUE';

    -- Then move processed files
    COPY FILES INTO @outbound_stage
    FROM @inbound_stage;
  SQL
}
```

### Adjusting Warehouse Size

Control compute costs by adjusting the warehouse size in `variables.tf`:

```hcl
variable "warehouse_sizes" {
  type    = list(string)
  default = ["XSMALL", "SMALL", "MEDIUM"]
}
```

The module uses the third element (`MEDIUM`) by default. Modify `locals.tf` to change the selection:

```hcl
locals {
  snowflake = {
    warehouse = {
      size = var.warehouse_sizes[0]  # Use XSMALL instead
    }
  }
}
```

### Adding File Filtering

Filter files by pattern in the task's SQL statement:

```sql
COPY FILES INTO @outbound_stage
FROM (
  SELECT relative_path
  FROM @inbound_stage
  WHERE relative_path LIKE '%.csv'
    AND relative_path NOT LIKE '%_backup%'
);
```

## Troubleshooting

### Common Issues

**Issue: Task not triggering despite files in S3**

```sql
-- Check stream contains data
SELECT * FROM your_stream_name;

-- Verify stream is not stale
SELECT SYSTEM$STREAM_HAS_DATA('your_stream_name');

-- Check task history
SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE NAME = 'your_task_name'
ORDER BY SCHEDULED_TIME DESC;
```

**Issue: Storage Integration authentication failure**

```sql
-- Verify storage integration configuration
DESC STORAGE INTEGRATION your_storage_integration;

-- Check IAM role trust relationship in AWS
-- Ensure external ID matches storage_aws_external_id from above
```

**Issue: Files not appearing in directory table**

```sql
-- Manually refresh the stage
ALTER STAGE your_stage_name REFRESH;

-- Check directory table contents
SELECT * FROM DIRECTORY(@your_stage_name);
```

### Debugging Commands

```bash
# Check Terraform state
terraform state list
terraform state show module.inbound_bucket.aws_s3_bucket.bucket

# Validate IAM role permissions
aws iam get-role --role-name role-<random-name>
aws iam get-role-policy --role-name role-<random-name> --policy-name policy-<random-name>

# Test S3 access
aws s3 ls s3://inbound-bucket-<random-name>/
```

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

**Maintained by:** Shane McGovern  
**Last Updated:** November 2025
