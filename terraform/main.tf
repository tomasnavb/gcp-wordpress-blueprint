# Terraform configuration for Google Cloud resources, including provider configuration and required provider versions.

terraform {
  required_version = ">= 1.15.7"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.25.0"
    }
    # Required by the official network module (terraform-google-modules/network/google). Same version as google.
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "7.25.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7" # 3.7 is the first version with the ephemeral random_password
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.14"
    }
  }
  backend "gcs" {
    # <project>/<environment>. The bucket is passed with -backend-config (<project_id>-tfstate).
    prefix = "wp-blueprint/prod"
  }
}

provider "google" {
  project = var.project_id
  region  = var.project_region
  zone    = var.project_zone
}
