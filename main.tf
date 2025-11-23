locals {
  role = lower("role-${replace(local.random, "_", "-")}")
}

resource "snowflake_warehouse" "warehouse" {
  name                = upper("WAREHOUSE_${replace(local.random, "-", "_")}")
  warehouse_size      = local.snowflake.warehouse.size
  initially_suspended = true
}

resource "snowflake_database" "database" {
  name = upper("DATABASE_${replace(local.random, "-", "_")}")
}

resource "snowflake_schema" "schema" {
  name     = upper("SCHEMA_${replace(local.random, "-", "_")}")
  database = snowflake_database.database.name
}

resource "aws_kms_key" "kms_key" {
  enable_key_rotation = true
}

module "inbound_bucket" {
  source            = "./catalog/modules/aws/s3"
  bucket            = lower("inbound-bucket-${replace(local.random, "_", "-")}")
  kms_master_key_id = aws_kms_key.kms_key.key_id
}

module "outbound_bucket" {
  source            = "./catalog/modules/aws/s3"
  bucket            = lower("outbound-bucket-${replace(local.random, "_", "-")}")
  kms_master_key_id = aws_kms_key.kms_key.key_id
}

resource "snowflake_storage_integration" "storage_integration" {
  name                      = upper("STORAGE_INTEGRATION_${replace(local.random, "-", "_")}")
  type                      = "EXTERNAL_STAGE"
  enabled                   = true
  storage_provider          = "S3"
  storage_aws_role_arn      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.role}"
  storage_allowed_locations = ["s3://${module.inbound_bucket.bucket}/", "s3://${module.outbound_bucket.bucket}/"]
}

resource "aws_iam_role" "role" {
  name = local.role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        AWS = snowflake_storage_integration.storage_integration.storage_aws_iam_user_arn
      }
      Condition = {
        StringEquals = {
          "sts:ExternalId" = snowflake_storage_integration.storage_integration.describe_output[0].storage_aws_external_id[0].value
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "policy" {
  name = lower("policy-${replace(local.random, "_", "-")}")
  role = aws_iam_role.role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = module.inbound_bucket.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${module.inbound_bucket.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = module.outbound_bucket.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${module.outbound_bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.kms_key.arn
      }
    ]
  })
}

module "inbound_stage" {
  source              = "./catalog/modules/snowflake/stage"
  storage_integration = snowflake_storage_integration.storage_integration.name
  database            = snowflake_database.database.name
  schema              = snowflake_schema.schema.name
  name                = upper("INBOUND_STAGE_${replace(local.random, "-", "_")}")
  url                 = "s3://${module.inbound_bucket.bucket}/"
}

resource "snowflake_stream_on_directory_table" "inbound_stream" {
  name     = upper("STREAM_${replace(local.random, "-", "_")}")
  database = snowflake_database.database.name
  schema   = snowflake_schema.schema.name
  stage    = module.inbound_stage.fully_qualified_name
}

resource "snowflake_task" "task" {
  database      = snowflake_database.database.name
  schema        = snowflake_schema.schema.name
  name          = upper("TASK_${replace(local.random, "-", "_")}")
  warehouse     = snowflake_warehouse.warehouse.fully_qualified_name
  when          = "SYSTEM$STREAM_HAS_DATA('${snowflake_stream_on_directory_table.inbound_stream.name}')"
  sql_statement = "COPY FILES INTO @${module.outbound_stage.fully_qualified_name} FROM @${module.inbound_stage.fully_qualified_name};"
  started       = true
  depends_on    = [snowflake_stream_on_directory_table.inbound_stream]
}

module "outbound_stage" {
  source              = "./catalog/modules/snowflake/stage"
  storage_integration = snowflake_storage_integration.storage_integration.name
  database            = snowflake_database.database.name
  schema              = snowflake_schema.schema.name
  name                = upper("OUTBOUND_STAGE_${replace(local.random, "-", "_")}")
  url                 = "s3://${module.outbound_bucket.bucket}/"
}