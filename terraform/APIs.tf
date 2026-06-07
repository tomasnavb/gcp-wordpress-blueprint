# List of APIs to enable for the environment
locals {
  services = [
    # --- Identity and Resource Management ---
    "iam.googleapis.com",                  # Identity and Access Management
    "cloudresourcemanager.googleapis.com", # Project resource management

    # --- Compute and Storage ---
    "compute.googleapis.com",  # Google Compute Engine
    "storage.googleapis.com",  # Google Cloud Storage
    "sqladmin.googleapis.com", # Cloud SQL Admin API

    # --- Cloud Functions 2nd Gen Dependencies ---
    "cloudfunctions.googleapis.com",   # Cloud Functions API
    "run.googleapis.com",              # Cloud Run (GCF v2 underlying infrastructure)
    "artifactregistry.googleapis.com", # Container image storage
    "cloudbuild.googleapis.com",       # Source code compilation
    "eventarc.googleapis.com",         # Event management for triggers

    # --- Cloud Scheduler ---
    "cloudscheduler.googleapis.com", # Cloud Scheduler API

    # --- Networking and Connectivity ---
    "vpcaccess.googleapis.com",         # Serverless VPC Access (for private DB connections)
    "servicenetworking.googleapis.com", # Service Peering for Cloud SQL/Managed Services
    "iap.googleapis.com",               # Identity-Aware Proxy

    # --- Security and Secret Management ---
    "secretmanager.googleapis.com", # Secure management of API keys and credentials
  ]
}

# Resource to enable all specified GCP services
resource "google_project_service" "gcp_services" {
  for_each = toset(local.services)

  project = var.project_id
  service = each.value

  # Prevent accidental disabling of APIs when removing resources
  disable_on_destroy = false
}

/**
 * TECHNICAL ARCHITECTURE NOTES:
 * 1. Artifact Registry is required for GCF v2 to store the built container images.
 * 2. Cloud Build is the engine that transforms Python code into executable artifacts.
 * 3. VPC Access Connector allows serverless functions to communicate with private 
 * PostgreSQL or MongoDB instances without exposing them to the public internet.
 */
