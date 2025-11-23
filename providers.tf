provider "aws" {
  region     = local.aws.provider.region
  access_key = local.aws.provider.access_key != "" ? local.aws.provider.access_key : null
  secret_key = local.aws.provider.secret_key != "" ? local.aws.provider.secret_key : null
}
provider "snowflake" {
  organization_name = local.snowflake.provider.organization_name
  account_name      = local.snowflake.provider.account_name
  user              = local.snowflake.provider.user
  password          = local.snowflake.provider.password != "" ? local.snowflake.provider.password : null
  role              = local.snowflake.provider.role
  params = {
    MULTI_STATEMENT_COUNT = "0"
  }
  preview_features_enabled = ["snowflake_storage_integration_resource", "snowflake_stage_resource"]
}