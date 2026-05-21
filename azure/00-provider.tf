terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}

provider "azurerm" {
  features {}
}

locals {
  project  = "rm562192"
  env      = "dev"
  location = "West Europe"
}
