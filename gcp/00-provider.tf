terraform {
  required_version = ">= 1.5"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 7.17" }
  }
}

provider "google" {
  project = local.project_id
  region  = local.region
}

locals {
  project    = "rm562192"
  env        = "dev"
  project_id = "fiap-multicloud"
  region     = "europe-west2"
}
