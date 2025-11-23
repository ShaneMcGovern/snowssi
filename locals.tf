resource "random_pet" "pet_name" {}

locals {
  random = random_pet.pet_name.id
  aws = {
    provider = {
      region     = var.region
      access_key = var.access_key
      secret_key = var.secret_key
    }
  }
  snowflake = {
    provider = {
      organization_name = var.organization_name
      account_name      = var.account_name
      user              = var.user
      password          = var.password
      role              = var.role
    }
    warehouse = {
      size = var.warehouse_sizes[2]
    }
  }
}