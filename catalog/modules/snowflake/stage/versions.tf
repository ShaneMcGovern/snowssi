terraform {
  required_version = "1.14.0"
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "2.10.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.13.1"
    }
  }
}