# WordPress on GCP — Infrastructure as Code

![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.0-7B42BC?logo=terraform&logoColor=white)
![Google Cloud](https://img.shields.io/badge/Google_Cloud-4285F4?logo=google-cloud&logoColor=white)
![Google Provider](https://img.shields.io/badge/Google_Provider-7.25.0-4285F4?logo=google-cloud&logoColor=white)
![IaC](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform&logoColor=white)

Production-grade WordPress infrastructure on Google Cloud Platform, fully provisioned with Terraform. Built as a portfolio project to demonstrate real-world cloud infrastructure engineering: network isolation, auto-healing compute, private database access, automated backups, and secrets management.

> **Note:** This is a portfolio project, not a production deployment. Some cost-optimized values (instance tier, disk size) differ from production recommendations documented in the code.

---

## Architecture

![Architecture Diagram](docs/architecture.jpeg)

### Overview

Traffic enters through a **Regional External Application Load Balancer** and reaches a **Regional Managed Instance Group** (MIG) of WordPress instances running in the production VPC. The MIG connects to **Cloud SQL (MySQL 8.4)** exclusively via private IP — no public database endpoint exists.

A separate **management VPC**, peered with the production VPC, hosts a management VM that reaches Cloud SQL through the **Cloud SQL Auth Proxy** for administrative tasks. SSH access to both VMs is exclusively through **Identity-Aware Proxy (IAP)** — no public IPs, no bastion hosts.

A **Cloud Function (v2)** triggered by **Cloud Scheduler** runs two automated backup strategies against Cloud SQL. Database credentials are stored in **Secret Manager** and read by the WordPress instances at startup.

---

## Key Design Decisions

### Regional MIG over Unmanaged Instance Group
The production workload uses a Regional Managed Instance Group with auto-healing, a named HTTP port for load balancer integration, and distribution across three zones (`europe-west1-b/c/d`). This provides zone-level fault tolerance and automatic instance replacement on health check failure — not achievable with a UMIG.

### Two-VPC Network Isolation
Production and management traffic are separated into two VPCs connected via VPC Peering. The production VPC handles all user-facing traffic; the management VPC is exclusively for administrative access. This limits the blast radius of a misconfiguration and reflects a real-world security boundary.

### Private IP for Cloud SQL
`ipv4_enabled = false` — the database has no public endpoint. Production instances connect via private IP within the same VPC. The management VM reaches it via VPC peering and Cloud SQL Auth Proxy. Private Service Access is configured for the service networking connection.

### IAP for SSH — No Public IPs, No Bastion
SSH access is granted through IAP tunnel access (`roles/iap.tunnelResourceAccessor`) to a specific operator email. No VM has an external IP address. No bastion host is required.

### Immutable Infrastructure with Packer
WordPress instances are deployed from a golden image built with Packer (`packer/wordpress.pkr.hcl`). The image includes WordPress, PHP, and all dependencies pre-installed. The MIG instance template references this image family — updates are rolled out by building a new image and triggering a rolling update.

### Two Backup Strategies
- **Export backup** (Cloud SQL export to GCS) — daily at midnight, 90-day retention via lifecycle rule. Full data portability.
- **Snapshot backup** (Cloud SQL backup run) — every 4 hours, 7-day retention. Fast point-in-time recovery.

Both are triggered by two Cloud Scheduler jobs invoking the same Cloud Function v2 with different payload types.

### Secret Manager for Credentials
WordPress database credentials (`db-name`, `db-user`, `db-password`, `db-host`, `db-instance-connection`) are stored as secrets and read by the MIG instances at startup via the startup script. The production VM service account has `roles/secretmanager.secretAccessor` on each secret individually (least privilege).

---

## GCP Services

| Service | Purpose |
|---|---|
| Compute Engine (Regional MIG) | Auto-healing WordPress instances across 3 zones |
| Cloud SQL (MySQL 8.4) | Managed relational database, private IP only |
| Cloud Load Balancing | Regional External Application LB with proxy-only subnet |
| Cloud NAT + Cloud Router | Outbound internet access without public IPs |
| Identity-Aware Proxy | Zero-trust SSH access to management VM |
| VPC Network Peering | Private connectivity between prod and mgmt VPCs |
| Secret Manager | Database credentials storage and access |
| Cloud Functions v2 | Serverless backup orchestration |
| Cloud Scheduler | Automated backup triggers (cron) |
| Cloud Storage | Backup exports (90d) and function source code |
| Packer (HashiCorp) | Golden image build pipeline |

---

## Project Structure

```
wordpress_site/
├── packer/                          # Golden image build
│   ├── wordpress.pkr.hcl            # Packer template
│   ├── variables.pkr.hcl
│   └── scripts/                     # Provisioning scripts
│
└── terraform/
    ├── main.tf                      # Providers, backend (GCS)
    ├── terraform.tfvars             # Variable values
    ├── APIs.tf                      # GCP API enablement
    ├── compute.tf                   # Management VM + MIG + LB modules
    ├── database.tf                  # Cloud SQL instance, database, user
    ├── functions.tf                 # Cloud Function + Scheduler modules
    ├── IAM.tf                       # Service accounts, roles, bindings
    ├── locals.tf                    # Shared locals (names, roles, secrets map)
    ├── networking.tf                # VPC modules + VPC Peering
    ├── outputs.tf
    ├── private_service_access.tf    # Private Service Access for Cloud SQL
    ├── secrets.tf                   # Secret Manager resources
    ├── storage.tf                   # GCS buckets + function source upload
    ├── variables_*.tf               # Variables split by domain
    └── modules/
        ├── cloud_scheduler/         # Cloud Scheduler job
        ├── external_lb/             # Regional External Application LB
        ├── mig/                     # Instance template + Regional MIG + Autoscaler
        └── networking/              # VPC, subnet, firewall rules, Cloud NAT
```

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [Packer](https://developer.hashicorp.com/packer/install) >= 1.9
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- A GCP project with billing enabled
- A GCS bucket for Terraform remote state

---

## Deployment

### 1. Authenticate

```bash
gcloud auth application-default login
```

### 2. Build the golden image

```bash
cd packer/
packer init .
packer build -var="project_id=YOUR_PROJECT_ID" wordpress.pkr.hcl
```

### 3. Configure Terraform backend

Edit `terraform/main.tf` and set the GCS bucket for your Terraform state:

```hcl
backend "gcs" {
  bucket = "your-terraform-state-bucket"
  prefix = "environments/prod"
}
```

### 4. Set required environment variable

The project ID is intentionally excluded from `terraform.tfvars` to avoid accidental commits.

```bash
export TF_VAR_project_id="your-gcp-project-id"
```

### 5. Deploy

```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

### Destroy

`deletion_protection` and `prevent_destroy` are enabled on the Cloud SQL instance. To destroy the environment, first disable them in `database.tf`, then run:

```bash
terraform destroy
```

---

## Modules

| Module | Description |
|---|---|
| `modules/networking` | VPC network, subnet, IAP/LB firewall rules, Cloud Router, Cloud NAT. All feature flags (`enable_nat`, `allow_external_lb`, `allow_ssh_from_iap`) are passed by the caller with no module-level defaults. |
| `modules/mig` | Instance template (Packer golden image), Regional MIG with distribution policy, global health check for auto-healing, and regional autoscaler with scale-in controls. |
| `modules/external_lb` | Proxy-only subnet, reserved external IP, forwarding rule, URL map, HTTP proxy, regional health check, and backend service wired to the MIG. |
| `modules/cloud_scheduler` | Cloud Scheduler job with OIDC-authenticated HTTP target, configurable retry policy, and cron schedule. Reused for both export and snapshot backup jobs. |

---

## Security Highlights

- No VM has a public IP address
- Cloud SQL is accessible only via private IP within the VPC
- SSH access exclusively through IAP (no open port 22 to the internet)
- Database credentials stored in Secret Manager, never in environment variables or files
- `project_id` excluded from version control — set via `TF_VAR_project_id`
- Cloud SQL instance has `deletion_protection = true` and `prevent_destroy = true`
- Least-privilege service accounts per workload (VM, function, scheduler)
- Custom IAM role for the backup function with only the required Cloud SQL permissions
