# Terraform configuration for Google Cloud resources, including provider configuration and required provider versions.

terraform {
  required_version = "1.15.7"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.25.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
  backend "gcs" {
    prefix = "environments/prod/networking"
  }
}

provider "google" {
  project = var.project_id
  region  = var.project_region
  zone    = var.project_zone
}
