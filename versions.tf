terraform {
  required_version = "1.14.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.21.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "2.10.1"
    }
  }
}