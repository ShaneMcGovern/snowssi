variable "region" {
  type    = string
  default = "us-east-1"
}

variable "access_key" {
  type      = string
  sensitive = true
  default   = null
}

variable "secret_key" {
  type      = string
  sensitive = true
  default   = null
}

variable "organization_name" {
  type    = string
  default = null
}

variable "account_name" {
  type    = string
  default = null
}

variable "user" {
  type    = string
  default = null
}

variable "password" {
  type      = string
  sensitive = true
  default   = null
}

variable "role" {
  type    = string
  default = "ACCOUNTADMIN"
}

variable "warehouse_sizes" {
  type    = list(string)
  default = ["XSMALL", "SMALL", "MEDIUM"]
}