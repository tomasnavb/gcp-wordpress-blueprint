# WordPress on GCP — Infrastructure as Code

![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.15.7-7B42BC?logo=terraform&logoColor=white)
![Google Cloud](https://img.shields.io/badge/Google_Cloud-4285F4?logo=google-cloud&logoColor=white)
![Google Provider](https://img.shields.io/badge/Google_Provider-7.25.0-4285F4?logo=google-cloud&logoColor=white)
![IaC](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform&logoColor=white)

> **Refactor in progress.** The project is being refactored towards a production-ready setup: a naming convention for every resource, the management VPC removed, a dedicated subnet for the image build, separate service accounts for plan, apply and image build, and an edge layer with Cloud Armor, Cloud CDN and a backend bucket for uploads. The [architecture diagram](#architecture) shows the target design; the rest of this README describes the code as it is today. Progress is tracked in [docs/to-do.md](docs/to-do.md).

**Terraform, Packer and Cloud Build code that deploys WordPress into a Google Cloud project of your own: an auto-healing managed instance group behind a global HTTPS load balancer, Cloud SQL on a private IP, scheduled backups and credentials in Secret Manager.** Infrastructure changes go through pull requests: plan on every PR, apply of the plan generated on `main` by a manual, approved trigger.

> **Note:** This is a portfolio project, not a production deployment. Some cost-optimized values (instance tier, disk size, a single instance at rest) differ from production recommendations documented in the code. Known gaps are listed in [Known Limitations](#known-limitations).

---

## Quickstart

The minimum sequence for a first deploy, from [Cloud Shell](https://shell.cloud.google.com). Each step is explained in [Deployment](#deployment).

```bash
# 1. Project with billing (Step 1)
export PROJECT_ID="your-gcp-project-id"
gcloud projects create $PROJECT_ID --name="WordPress on GCP"
gcloud config set project $PROJECT_ID
gcloud billing projects link $PROJECT_ID --billing-account=BILLING_ACCOUNT_ID

# 2. Repository and variables (Steps 2 and 3); set domain_names in terraform/terraform.tfvars
gh repo clone YOUR_GITHUB_USERNAME/gcp-wordpress-blueprint
cd gcp-wordpress-blueprint
export REPO_NAME="gcp-wordpress-blueprint"
export REPO_OWNER="your-github-username-or-org"
export IAP_USER_EMAIL="you@example.com"
export RESERVE_LB_IP="true"

# 3. Connect the repository in the console (Step 4):
#    Cloud Build → Triggers → Connect Repository → GitHub

# 4. Bootstrap (Step 5); then point your domain's DNS A record to the IP it prints
bash configs/setup.sh

# 5. First image, plan and apply (Steps 6 to 8)
CB_SA="projects/${PROJECT_ID}/serviceAccounts/terraform-cloud-build@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud builds submit --project=$PROJECT_ID --config=cloudbuild/packer.yaml \
  --substitutions="_PROJECT_ID=$PROJECT_ID,_ZONE=europe-west1-b,_NETWORK=default,_SUBNETWORK=default,_USE_IAP=false" \
  --service-account="$CB_SA"
gcloud builds submit --project=$PROJECT_ID --config=cloudbuild/terraform-plan.yaml \
  --substitutions="_PROJECT_ID=$PROJECT_ID,_STATE_BUCKET=${PROJECT_ID}-wordpress-terraform-state,_IAP_USER_EMAIL=$IAP_USER_EMAIL,_SAVE_PLAN=true" \
  --service-account="$CB_SA"
gcloud builds submit --project=$PROJECT_ID --config=cloudbuild/terraform-apply.yaml \
  --substitutions="_PROJECT_ID=$PROJECT_ID,_STATE_BUCKET=${PROJECT_ID}-wordpress-terraform-state,_PLAN_BUILD_ID=PLAN_BUILD_ID" \
  --service-account="$CB_SA"
```

`PLAN_BUILD_ID` is the `BUILD_ID` printed by the plan build. Tear everything down with [Destroy](#destroy) when you are done: the regional Cloud SQL instance is billed while it is up.

---

## Architecture

<a href="docs/architecture-v2.png"><img src="docs/architecture-v2.png" alt="Target architecture" width="100%"></a>

*Click the diagram to open it at full size.*

> **Target architecture.** The diagram shows the design the refactor announced at the top is moving to, not the code as it is today: resource names, the edge layer, the service accounts and the absence of the management VPC are not implemented yet. Not shown: `build-subnet-prod-europe-west1`, a subnet of the same VPC that only hosts the ephemeral Packer VM during an image build.

### Overview

Traffic enters through a **Global External Application Load Balancer**, which terminates HTTPS with a Google-managed certificate and redirects HTTP to HTTPS, and reaches a **Regional Managed Instance Group** (MIG) of WordPress instances running in the production VPC. The MIG connects to **Cloud SQL (MySQL 8.4)** exclusively via private IP — no public database endpoint exists. WordPress uploads are stored in a **Cloud Storage** bucket that every instance mounts, so the instances keep no state.

A separate **management VPC**, peered with the production VPC, hosts a management VM intended for administrative access to Cloud SQL through the **Cloud SQL Auth Proxy** (that access does not work yet, see [Known Limitations](#known-limitations)), and the temporary VM of every image build. SSH access to both VMs is exclusively through **Identity-Aware Proxy (IAP)** — no public IPs, no bastion hosts.

A **Cloud Function (v2)** triggered by **Cloud Scheduler** runs two automated backup strategies against Cloud SQL. Database credentials are stored in **Secret Manager** and read by the WordPress instances at startup.

---

## Key Design Decisions

### Regional MIG over Unmanaged Instance Group
The production workload uses a Regional Managed Instance Group with auto-healing, a named HTTP port for load balancer integration, and distribution across three zones (`europe-west1-b/c/d`). An instance that fails its health check is replaced automatically, and the autoscaler adds instances under load (1 to 3) — not achievable with a UMIG.

To keep costs down, `min_replicas = 1`: at rest a single instance runs, so losing its zone means downtime until the MIG creates a replacement in another zone. Zone-level fault tolerance requires `min_replicas` of at least 2.

### Two-VPC Network Isolation
Production and management traffic are separated into two VPCs connected via VPC Peering. The production VPC handles all user-facing traffic; the management VPC is for administrative access and for the image builds. This limits the blast radius of a misconfiguration and reflects a real-world security boundary.

### Private IP for Cloud SQL
`ipv4_enabled = false` — the database has no public endpoint. Production instances connect via private IP within the same VPC, through a Private Service Access connection (`private_service_access.tf`).

VPC peering is not transitive, so the management VM cannot reach that private IP through its peering with the production VPC. Admin access from the management VM is not working yet (see [Known Limitations](#known-limitations)).

### IAP for SSH — No Public IPs, No Bastion
SSH access is granted through IAP tunnel access (`roles/iap.tunnelResourceAccessor`) to a specific operator email. No VM has an external IP address. No bastion host is required.

The operator email is not committed: it is passed to the pipeline as the `_IAP_USER_EMAIL` substitution and validated at plan time. In a production environment the binding would go to a Google group (`group:infra-admins@example.com`) instead of a user, so that team changes do not require a Terraform change.

### Global HTTPS Load Balancer with a Managed Certificate
The load balancer is global rather than regional because Google-managed SSL certificates, which Google issues and renews on its own, attach to the global external Application Load Balancer. The certificate is only issued once the DNS A record of the domain points to the load balancer IP, and that can take from 15 minutes to over an hour after the first deploy.

- **TLS ends at the load balancer.** Backends receive plain HTTP on port 80 inside the VPC. WordPress reads the `X-Forwarded-Proto` header the load balancer sets, so it knows the visitor is on HTTPS; without that it produces blocked `http://` assets and a redirect loop in the admin area. The block is baked into the image by `packer/scripts/install.sh`.
- **HTTP redirects to HTTPS.** A second forwarding rule on port 80, on the same IP, answers every request with a 301 to HTTPS.
- **Minimum TLS 1.2.** An SSL policy (`MODERN` profile) replaces the default one, which still accepts TLS 1.0.
- **One firewall rule for the Google front ends.** With a global load balancer, health check probes and proxied client traffic reach the backends from the same Google ranges (`35.191.0.0/16`, `130.211.0.0/22`). The rule lives in the load balancer module and targets only instances tagged `backend-service`.

### Reserved IP for the Load Balancer
A deploy that creates its own IP gets a different address every time, so the DNS record has to be updated and the certificate waits for DNS again. With `lb_use_reserved_ip = true` (the default) the load balancer uses a global IP reserved once by `configs/setup.sh`, outside Terraform. It survives `terraform destroy`, so the DNS record is set once.

A reserved IP is billed while no load balancer is using it. For a portfolio project that is torn down between tests, release it when a test session ends (see [Destroy](#destroy)), or set both `RESERVE_LB_IP` and `lb_use_reserved_ip` to `false` to let Terraform create and destroy the IP with the load balancer.

### Stateless WordPress Instances
Instances in a MIG are replaced at any time: auto-healing, a new image, scaling in. Anything written to their disks is lost, and a file written by one instance does not exist on the others. WordPress keeps writing two kinds of content at runtime, and each is handled differently:

- **Uploads (media).** Stored in the `uploads/` folder of the statics bucket (`wordpress-statics-<project_id>`), which every instance mounts at `wp-content/uploads` with [Cloud Storage FUSE](https://docs.cloud.google.com/storage/docs/cloud-storage-fuse/overview). An image uploaded through one instance is visible from all of them and survives their replacement. WordPress needs no plugin and no change: it writes to what looks like a local folder.
- **Plugins and themes.** Part of the image. `DISALLOW_FILE_MODS` stops the admin panel from installing, updating or editing them, since a change made there would exist on one instance only. A new plugin, or an update, is a new image and a rolling update.

How the mount is wired:

- The image only installs `gcsfuse` (pinned version, from Google's signed apt repository) and creates the mount point. It is the same image for any project.
- The bucket name and the folder to mount reach the instances as instance metadata (`statics-bucket` and `uploads-folder`), set by Terraform from the same values it uses to create the bucket and the folder, so what is created and what is mounted cannot differ. The name itself is fixed in `locals.tf` and is not a variable: the bucket has one specific job, and `configs/destroy.sh` relies on the same name. The startup script reads it from the metadata server and mounts the `uploads/` folder of the bucket (`--only-dir`) on every boot. The bucket is laid out with one folder per kind of content, so other folders can be added without moving the uploads.
- `gcsfuse` authenticates as the instance service account, which has `roles/storage.objectUser` on that bucket only. No service account keys.
- The mount happens before the readiness marker, so an instance that fails to mount is reported unhealthy and replaced.
- The bucket holds data: `force_destroy = false`, protected in the destructive change check, versioned (overwritten or deleted files kept for 30 days), and without a retention policy, which Cloud Storage FUSE cannot write to.

Cloud Storage FUSE is not a POSIX file system: it has higher latency than a local disk and no file locking. That suits uploads, which are written once and read many times. Serving them straight from the bucket through the load balancer, without going through the instances, is a possible next step.

### Immutable Infrastructure with Packer
WordPress instances are deployed from a golden image built with Packer (`packer/wordpress.pkr.hcl`). The image includes WordPress, PHP, and all dependencies pre-installed. Terraform resolves the `wordpress-golden` image family to the concrete latest image on every plan, so a new build shows up as an instance template replacement and the MIG rolls it out.

The build VM has no external IP: Packer reaches it through an IAP tunnel in the management VPC, the same way an operator does.

### Two Backup Strategies
- **Export backup** (Cloud SQL export to a SQL file in Cloud Storage) — daily at midnight (`Europe/Paris`), deleted after 90 days by a lifecycle rule on the backup bucket. Full data portability.
- **Snapshot backup** (on-demand Cloud SQL backup) — every 4 hours. Fast to take and to restore. Cloud SQL does not delete on-demand backups by itself, and the project does not delete them yet, so they accumulate (see [Known Limitations](#known-limitations)).

Both are triggered by two Cloud Scheduler jobs invoking the same Cloud Function v2 with different payload types.

Independently of the function, the Cloud SQL instance has automated daily backups and binary logging enabled, with Cloud SQL's default retention, which is what allows point-in-time recovery.

### Dedicated Build Identity for the Backup Function
A Cloud Function v2 involves three identities, and they are easy to confuse:

| Identity | What it does | In this project |
|---|---|---|
| Deployer | Creates the function | `terraform-cloud-build`, the pipeline service account |
| Build | Runs the Cloud Build that turns the source into a container image | `cloudsql-backup-fn-build-sa` |
| Runtime | Runs the function code | `cloudsql-backup-fn-sa` |

Left unset, the build identity is the Compute Engine default service account, which then needs broad roles added by hand. This project gives the build its own service account with three roles:

- `roles/logging.logWriter`, to write the build logs.
- `roles/artifactregistry.writer`, to push the image to the `gcf-artifacts` repository.
- `roles/storage.objectViewer`, to read the source.

Two details shaped how those roles are granted:

- **The build does not read the source from the bucket you upload it to.** Cloud Functions first copies the zip to a bucket it creates itself, `gcf-v2-sources-<project number>-<region>`, and builds from there. That bucket and the `gcf-artifacts` repository do not exist before the first deploy, so the roles cannot be bound on them beforehand and are granted at project level. An IAM condition limits the storage role to buckets named `gcf-v2-sources-*`; without it the build identity could read every bucket in the project, including the database exports.
- **IAM bindings take time to propagate.** Created in the same apply as the function, they are not effective yet when the build starts a few seconds later, and the build fails for lack of a permission that is already granted. A 120-second wait (`time_sleep`) sits between the bindings and the function.

### Secret Manager for Credentials
WordPress database credentials (`wordpress-db-name`, `wordpress-db-user`, `wordpress-db-password`, `wordpress-db-host`, `wordpress-db-instance-connection`) are stored as secrets and read by the MIG instances at startup via the startup script, which writes them into `wp-config.php` on the instance. The production VM service account has `roles/secretmanager.secretAccessor` on each secret individually (least privilege).

**The database password never reaches the Terraform state or a saved plan.** Both are files in a bucket, and a secret stored in them is a secret stored outside Secret Manager. Terraform generates and delivers the password with ephemeral resources and write-only arguments:

```text
ephemeral random_password ──► Secret Manager ──(ephemeral read)──► Cloud SQL user
     generated per run        secret_data_wo                        password_wo
```

- An **ephemeral resource** exists only while Terraform runs: its value is used and discarded.
- A **write-only argument** is sent to the API and not stored. Terraform cannot tell whether it changed, so each one comes with a version number, and the value is sent again only when that number changes.
- **Secret Manager is the source of truth.** The Cloud SQL user takes the password from the secret, not from the generator, so the two always hold the same value, even if an apply fails halfway. It is read with an `ephemeral` block and not a `data` source, which would store it in the state.

The other four values (database name, user, host and connection string) are not sensitive and are stored as regular secret versions. See [Rotate the database password](#rotate-the-database-password) for how the version number is used.

---

## GCP Services

| Service | Purpose |
|---|---|
| Compute Engine (Regional MIG) | Auto-healing WordPress instances across 3 zones |
| Cloud SQL (MySQL 8.4) | Managed relational database, regional (high availability), private IP only |
| Cloud Load Balancing | Global External Application LB: HTTPS with a Google-managed certificate, HTTP to HTTPS redirect, TLS 1.2 minimum |
| Cloud NAT + Cloud Router | Outbound internet access without public IPs |
| Identity-Aware Proxy | SSH to the management VM, the WordPress instances and the Packer build VM, none of which has a public IP |
| VPC Network Peering | Private connectivity between prod and mgmt VPCs |
| Secret Manager | Database credentials storage and access |
| Cloud Functions v2 | Serverless backup orchestration |
| Cloud Scheduler | Automated backup triggers (cron) |
| Cloud Storage | Backup exports (90d), function source code, and WordPress uploads mounted on the instances with Cloud Storage FUSE |
| Packer (HashiCorp) | Golden image build pipeline |

---

## Project Structure

```text
gcp-wordpress-blueprint/
├── README.md
├── docs/
│   ├── architecture-v2.png          # Target architecture diagram (refactor in progress)
│   ├── architecture.jpeg            # Previous architecture diagram, outdated
│   ├── to-do.md                     # Pending tasks and their status
│   ├── devlogs/                     # Problems found during deploys, their causes and fixes
│   └── screenshots/                 # Images used in the Screenshots section
│
├── configs/
│   ├── setup.sh                     # One-time bootstrap: APIs, state bucket, load balancer IP, Cloud Build SA, IAM, triggers
│   └── destroy.sh                   # gcloud steps around terraform destroy: empty the data buckets, delete the peering if needed
│
├── cloudbuild/
│   ├── packer.yaml                  # Cloud Build pipeline: install pinned Packer, golden image build
│   ├── terraform-plan.yaml          # Cloud Build pipeline: init, fmt, validate, plan, destructive change report, artifact upload
│   ├── terraform-apply.yaml         # Cloud Build pipeline: init, download plan, destructive change check, apply
│   └── scripts/
│       └── check_destructive.py     # Reports destructive changes on plan; blocks them on apply unless explicitly allowed
│
├── packer/
│   ├── wordpress.pkr.hcl            # Packer template
│   ├── variables.pkr.hcl
│   └── scripts/
│       └── install.sh               # WordPress + PHP + Apache provisioning, HTTPS proxy config
│
└── terraform/
    ├── main.tf                      # Providers, backend (GCS, bucket via -backend-config)
    ├── terraform.tfvars             # Variable values (project_id and iap_user_email are passed by the pipeline)
    ├── .terraform.lock.hcl          # Provider version lock (committed for CI/CD consistency)
    ├── APIs.tf                      # GCP API enablement
    ├── compute.tf                   # Management VM + MIG + LB modules
    ├── database.tf                  # Cloud SQL instance, database, user, password generated with ephemeral resources
    ├── functions.tf                 # Cloud Function v2 + Cloud Scheduler modules
    ├── IAM.tf                       # Service accounts, custom role, bindings, IAM propagation waits
    ├── locals.tf                    # Shared locals (names, service account members, secret names and values)
    ├── networking.tf                # VPC modules + VPC Peering
    ├── outputs.tf                   # Load balancer IP, site URLs, certificate name
    ├── private_service_access.tf    # Private Service Access for Cloud SQL
    ├── secrets.tf                   # Secret Manager secrets and versions (password write-only)
    ├── storage.tf                   # Backup, function source and statics buckets, uploads folder, function zip
    ├── variables_*.tf               # Variables split by domain
    ├── scripts/
    │   ├── startup-prod.sh          # MIG instance startup: fetch secrets, configure wp-config.php, mount uploads
    │   └── startup-mgmt.sh          # Management VM startup: install Cloud SQL Auth Proxy
    ├── functions/
    │   └── db-backup/
    │       ├── main.py              # Cloud Function: snapshot and export backup logic
    │       └── requirements.txt
    └── modules/                     # Each module has a README generated with terraform-docs
        ├── cloud_scheduler/         # Cloud Scheduler job with OIDC auth and retry policy
        ├── global_external_lb/      # Global IP, managed certificate, HTTPS and HTTP forwarding rules, backend service, firewall
        ├── mig/                     # Instance template, Regional MIG, autoscaler, health check
        └── networking/              # VPC, subnet, IAP firewall rule, Cloud Router, Cloud NAT
```

---

## Prerequisites

- A Google Cloud account with a billing account. The project itself is created in [Step 1](#step-1-create-the-gcp-project-and-enable-billing)
- A GitHub account with this repository forked or cloned
- A domain name whose DNS records you control (the managed certificate is issued for it)
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (preinstalled in Cloud Shell)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.15.7, only for the [Destroy](#destroy), which runs outside the pipeline. Check `terraform version` in Cloud Shell before using it

The CI/CD pipeline runs entirely on **Cloud Build** with pinned versions (Terraform 1.15.7, Packer 1.16.1) — Terraform and Packer are not required locally to deploy.

---

## Configuration

Nothing in the repository holds values specific to one deployment except the domain. The rest comes from three places.

**Bootstrap variables**, exported in the shell before running `configs/setup.sh` ([Step 3](#step-3-set-the-deployment-variables)):

| Name | Type | Default | Description |
|---|---|---|---|
| `PROJECT_ID` | string | — (required) | GCP project to deploy into |
| `REPO_NAME` | string | — (required) | GitHub repository the triggers watch |
| `REPO_OWNER` | string | — (required) | GitHub user or organization that owns the repository |
| `IAP_USER_EMAIL` | string | — (required) | Google account granted SSH access through IAP. Stored in the trigger substitutions |
| `RESERVE_LB_IP` | string | `true` | `true` reserves a global IP for the load balancer outside Terraform. Must match `lb_use_reserved_ip` |

**Cloud Build substitutions**, set on the triggers by `configs/setup.sh` or passed at run time:

| Name | Type | Default | Description |
|---|---|---|---|
| `_PROJECT_ID` | string | — (required) | Project ID; becomes `TF_VAR_project_id` |
| `_IAP_USER_EMAIL` | string | — (required) | Operator email; becomes `TF_VAR_iap_user_email` (plan pipeline) |
| `_STATE_BUCKET` | string | — (required) | Bucket that holds the state and the saved plans, `<project_id>-wordpress-terraform-state` |
| `_SAVE_PLAN` | string | `false` | `true` uploads the plan so it can be applied. Only `terraform-plan-main` sets it |
| `_PLAN_BUILD_ID` | string | — (required) | `BUILD_ID` of the plan to apply (apply pipeline) |
| `_ALLOW_DESTRUCTIVE` | string | `false` | `true` lets the apply run a plan that destroys or replaces resources, except protected ones |
| `_USE_IAP` | string | `true` | Packer reaches the build VM through IAP. `false` only for the first build, in the `default` network |

**Terraform variables.** Defined in `terraform/variables_*.tf`; their values are in [terraform/terraform.tfvars](terraform/terraform.tfvars), except `project_id` and `iap_user_email`, which the pipeline passes. The ones a deployer is most likely to change:

| Name | Type | Default | Description |
|---|---|---|---|
| `project_id` | `string` | — (required) | Passed by the pipeline from `_PROJECT_ID` |
| `iap_user_email` | `string` | — (required) | Passed by the pipeline from `_IAP_USER_EMAIL`. Validated as an email address at plan time |
| `domain_names` | `list(string)` | — (required) | Domains of the managed certificate. Set your own in `terraform.tfvars` |
| `lb_use_reserved_ip` | `bool` | — (required) | `true` in `terraform.tfvars`: use the IP reserved by `setup.sh`. Must match `RESERVE_LB_IP` |
| `db_password_version` | `number` | — (required) | `1` in `terraform.tfvars`. Whole number, 1 or greater; raise it to [rotate the password](#rotate-the-database-password) |
| `machine_type` | `string` | — (required) | `e2-standard-2` in `terraform.tfvars`. Machine type of the WordPress instances |
| `min_replicas` / `max_replicas` | `number` | — (required) | `1` / `3` in `terraform.tfvars`. Autoscaler limits |
| `instance_tier` | `string` | — (required) | `db-custom-2-4096` in `terraform.tfvars`, reduced for cost (production recommendation in the file: `db-custom-4-16384`) |
| `instance_availability_type` | `string` | `"REGIONAL"` | Cloud SQL availability. `ZONAL` costs less and has no failover |

The region (`europe-west1`) is set in several places: `terraform.tfvars`, `configs/setup.sh` (state bucket) and the Packer trigger substitutions (`_ZONE`). Changing it means changing all of them.

---

## Deployment

The deployment is split into two phases: a one-time **bootstrap** that sets up Cloud Build, and a **CI/CD pipeline** for all subsequent infrastructure changes.

### Phase 1 — Bootstrap (one-time)

#### Step 1: Create the GCP project and enable billing

Everything below runs in [Cloud Shell](https://shell.cloud.google.com). The deployment needs its own project with a billing account linked: Compute Engine, Cloud SQL and Cloud Build cannot be enabled without one.

```bash
export PROJECT_ID="your-gcp-project-id"      # globally unique, 6 to 30 characters

gcloud projects create $PROJECT_ID --name="WordPress on GCP"
gcloud config set project $PROJECT_ID

# Link a billing account
gcloud billing accounts list
gcloud billing projects link $PROJECT_ID --billing-account=BILLING_ACCOUNT_ID
```

Both can also be done in the console: *IAM & Admin → Create a Project*, then *Billing → Link a billing account*. To use an existing project, export `PROJECT_ID` and skip the rest of this step.

Confirm billing is active before continuing:

```bash
gcloud billing projects describe $PROJECT_ID --format="value(billingEnabled)"   # must print True
```

> **Cost:** the environment is billed while it is up, mainly the regional Cloud SQL instance. See [Destroy](#destroy) to tear it down.

#### Step 2: Clone the repository in Cloud Shell

```bash
gh auth login
gh repo clone YOUR_GITHUB_USERNAME/gcp-wordpress-blueprint
cd gcp-wordpress-blueprint
```

#### Step 3: Set the deployment variables

`PROJECT_ID` is already exported from Step 1. Export the rest in the same shell. `configs/setup.sh` reads them, and the commands of the next steps use them too, so no file is edited with your own values:

```bash
export REPO_NAME="gcp-wordpress-blueprint"
export REPO_OWNER="your-github-username-or-org"
export IAP_USER_EMAIL="you@example.com"     # Google account granted SSH access through IAP
export RESERVE_LB_IP="true"                 # reserve a static IP for the load balancer (see below)
```

The script stops with an error if `PROJECT_ID` or any of the first three is missing.

Set your domain in `terraform/terraform.tfvars`:

```hcl
domain_names       = ["wordpress.example.com"]
lb_use_reserved_ip = true   # must match RESERVE_LB_IP
```

#### Step 4: Connect the GitHub repository to Cloud Build

This step requires OAuth authorization and **cannot** be done via `gcloud`. Do it manually:

> GCP Console → Cloud Build → Triggers → Connect Repository → GitHub

Once the repository is listed as connected, proceed to the next step.

#### Step 5: Run the bootstrap script

```bash
chmod +x configs/setup.sh
bash configs/setup.sh
```

This creates:
- The APIs Terraform needs before it can enable the rest (`serviceusage`, `cloudresourcemanager`, `iam`, `cloudbuild`, `compute`)
- Terraform state bucket (`PROJECT_ID-wordpress-terraform-state`) with versioning and 30-day plan artifact lifecycle
- Cloud Build service account (`terraform-cloud-build`) with all required IAM roles
- Four Cloud Build triggers: `packer-build`, `terraform-plan-pr`, `terraform-plan-main`, `terraform-apply`
- With `RESERVE_LB_IP=true`, a global static IP for the load balancer (`wordpress-prod-lb-ip-global-external-lb`)

Before creating the triggers the script asks whether the repository is connected (Step 4). Answering anything but `y` skips the triggers.

The script prints the reserved IP. **Create a DNS A record for your domain pointing to it now**: the certificate cannot be issued until that record resolves, so the sooner it propagates the better.

---

### Phase 2 — First deploy

#### Step 6: Build the golden image (Packer)

Manually submit the Packer build (Cloud Build trigger fires automatically on future pushes to `packer/**`):

```bash
gcloud builds submit \
  --project=$PROJECT_ID \
  --config=cloudbuild/packer.yaml \
  --substitutions="_PROJECT_ID=$PROJECT_ID,_ZONE=europe-west1-b,_NETWORK=default,_SUBNETWORK=default,_USE_IAP=false" \
  --service-account="projects/${PROJECT_ID}/serviceAccounts/terraform-cloud-build@${PROJECT_ID}.iam.gserviceaccount.com"
```

> **Note:** This first build is the one exception to the "no public IPs" rule. The management VPC, its IAP firewall rule and the IAP API are created by Terraform, and Terraform needs the image to exist first. So the first build runs in the `default` network with `_USE_IAP=false`: the temporary build VM gets an external IP and Packer connects to it over SSH directly. The VM is deleted when the build ends.
>
> Every later build runs from the `packer-build` trigger with `_USE_IAP=true`: the build VM is created in `wordpress-mgmt-vpc` with no external IP and Packer connects through an IAP tunnel.

#### Step 7: Generate the Terraform plan

```bash
gcloud builds submit \
  --project=$PROJECT_ID \
  --config=cloudbuild/terraform-plan.yaml \
  --substitutions="_PROJECT_ID=$PROJECT_ID,_STATE_BUCKET=${PROJECT_ID}-wordpress-terraform-state,_IAP_USER_EMAIL=$IAP_USER_EMAIL,_SAVE_PLAN=true" \
  --service-account="projects/${PROJECT_ID}/serviceAccounts/terraform-cloud-build@${PROJECT_ID}.iam.gserviceaccount.com"
```

`_SAVE_PLAN=true` uploads the plan so it can be applied. The build output ends with the `BUILD_ID`. Copy it — you will need it in the next step.

> The plan is saved to `gs://PROJECT_ID-wordpress-terraform-state/plans/BUILD_ID/`.
> Review `plan.txt` before applying.

#### Step 8: Apply the plan

Replace `PLAN_BUILD_ID` with the ID from Step 7:

```bash
gcloud builds submit \
  --project=$PROJECT_ID \
  --config=cloudbuild/terraform-apply.yaml \
  --substitutions="_PROJECT_ID=$PROJECT_ID,_STATE_BUCKET=${PROJECT_ID}-wordpress-terraform-state,_PLAN_BUILD_ID=PLAN_BUILD_ID" \
  --service-account="projects/${PROJECT_ID}/serviceAccounts/terraform-cloud-build@${PROJECT_ID}.iam.gserviceaccount.com"
```

Once the apply completes, the last step prints the Terraform outputs: `load_balancer_ip`, `site_urls` and `ssl_certificate_name`.

If the IP was not reserved beforehand (`lb_use_reserved_ip = false`), create the DNS A record now with `load_balancer_ip`.

WordPress is not reachable right away. The instances need a few minutes to boot, and the managed certificate is issued only after Google sees the DNS record pointing to the load balancer, which takes from 15 minutes to over an hour. Until then browsers show an SSL error. Check progress with:

```bash
gcloud compute ssl-certificates describe SSL_CERTIFICATE_NAME \
  --project=$PROJECT_ID \
  --global \
  --format="value(managed.status, managed.domainStatus)"
```

| Status | Meaning |
|---|---|
| `PROVISIONING` | Being issued. Normal after a deploy |
| `ACTIVE` | Issued. The site is available at the URLs in `site_urls` |
| `FAILED_NOT_VISIBLE` | Google does not see the DNS record pointing to the load balancer IP |

---

### CI/CD flow (ongoing changes)

What is deployed always comes from `main`: a pull request is reviewed with a plan, but only the plan generated after the merge can be applied.

| Event | Trigger | What runs |
|---|---|---|
| Pull Request targeting `main` | `terraform-plan-pr` (automatic) | `cloudbuild/terraform-plan.yaml` — plan for review. Not saved, cannot be applied |
| Push to `main` with changes in `terraform/**` | `terraform-plan-main` (automatic) | `cloudbuild/terraform-plan.yaml` — same plan, saved to the state bucket |
| Manual run after reviewing the saved plan | `terraform-apply` (manual, requires approval) | `cloudbuild/terraform-apply.yaml` — destructive change check, then apply |
| Push to `main` with changes in `packer/**` | `packer-build` (automatic) | `cloudbuild/packer.yaml` — builds a new golden image |

**To apply the plan generated on `main`**, use the `BUILD_ID` of the `terraform-plan-main` run:

```bash
gcloud beta builds triggers run terraform-apply \
  --project=$PROJECT_ID \
  --branch=main \
  --substitutions=_PLAN_BUILD_ID=PLAN_BUILD_ID_FROM_MAIN
```

A saved plan goes stale as soon as the state changes: if two pull requests are merged in a row, Terraform only accepts the most recent plan.

> **Note:** a merge that changes both `packer/**` and `terraform/**` starts `packer-build` and `terraform-plan-main` at the same time. That plan resolves the image before the new one exists. Do not apply it: wait for the image build and run `terraform-plan-main` by hand, as in [Update the WordPress image](#update-the-wordpress-image).

#### Destructive changes

Both plan triggers list every resource the plan would destroy or replace, without failing. The check is enforced at apply time, on the exact plan being applied:

| Plan contains | Apply result |
|---|---|
| No destroy or replace | Applies |
| Replace of an instance template, an IAM binding or the function source zip | Applies — routine, no data involved |
| Any other destroy or replace | Rejected unless `_ALLOW_DESTRUCTIVE=true` is passed |
| Destroy or replace of the Cloud SQL instance, its database, the backup bucket or the statics bucket | Always rejected |

To apply a plan with destructive changes after reviewing them:

```bash
gcloud beta builds triggers run terraform-apply \
  --project=$PROJECT_ID \
  --branch=main \
  --substitutions=_PLAN_BUILD_ID=PLAN_BUILD_ID_FROM_MAIN,_ALLOW_DESTRUCTIVE=true
```

The protected resources are listed in [cloudbuild/scripts/check_destructive.py](cloudbuild/scripts/check_destructive.py). The flag does not override them; removing one from the list takes a reviewed commit.

---

## Destroy

The pipeline cannot destroy the environment: the database and the data buckets are protected. Tear it down from Cloud Shell. [configs/destroy.sh](configs/destroy.sh) holds the gcloud steps that `terraform destroy` needs around it; it asks to type the project ID before changing anything.

First empty the backup and statics buckets. They keep `force_destroy = false` on purpose, so Terraform refuses to delete them while they hold objects, and their content is created by Cloud SQL and by WordPress, not by Terraform. This deletes the database exports and the uploads for good, all versions included:

```bash
bash configs/destroy.sh empty-buckets
```

Then run the destroy (Terraform >= 1.15.7, see [Prerequisites](#prerequisites)):

```bash
cd terraform
mkdir -p tmp
terraform init -backend-config="bucket=${PROJECT_ID}-wordpress-terraform-state"
export TF_VAR_project_id=$PROJECT_ID
export TF_VAR_iap_user_email=$IAP_USER_EMAIL
terraform destroy
```

If the destroy stops on `google_service_networking_connection.private_connection` with `Producer services (e.g. CloudSQL, ...) are still using this connection`, Google is still holding the private connection of the deleted Cloud SQL instance. The connection has `deletion_policy = "ABANDON"` to avoid this, so it should not happen; if it does, or if the destroy stops on the reserved range or the VPC instead, delete the peering from the VPC side and run the destroy again:

```bash
bash configs/destroy.sh delete-peering
terraform destroy
```

`terraform destroy` does not release the reserved load balancer IP, because it is not managed by Terraform. Keep it to redeploy later without touching DNS, or release it to stop paying for it:

```bash
gcloud compute addresses delete wordpress-prod-lb-ip-global-external-lb \
  --project=$PROJECT_ID \
  --global
```

> **Portfolio note:** `deletion_protection` and `prevent_destroy` are set to `false` in this project to allow easy teardown during testing. In a production environment both should be set to `true` in [terraform/database.tf](terraform/database.tf).

---

## Operations

### SSH access via IAP

```bash
# Management VM
gcloud compute ssh wordpress-mgmt-vm \
  --zone=europe-west1-b \
  --project=$PROJECT_ID \
  --tunnel-through-iap

# Production instance (MIG)
gcloud compute ssh INSTANCE_NAME \
  --zone=ZONE \
  --project=$PROJECT_ID \
  --tunnel-through-iap
```

### Trigger a manual backup

```bash
# Snapshot (fast, seconds)
gcloud functions call wordpress-fn-db-backup-prod \
  --region=europe-west1 \
  --project=$PROJECT_ID \
  --data='{"type": "snapshot"}'

# Export to GCS (full SQL dump)
gcloud functions call wordpress-fn-db-backup-prod \
  --region=europe-west1 \
  --project=$PROJECT_ID \
  --data='{"type": "export"}'
```

View snapshots:

```bash
gcloud sql backups list --instance=wordpress-prod-db --project=$PROJECT_ID
```

View exports:

```bash
gcloud storage ls gs://wordpress-db-backups-${PROJECT_ID}/exports/
```

### Rotate the database password

The password is written only when `db_password_version` changes, so rotating it is raising that number by one in `terraform/terraform.tfvars`, through a pull request like any other change:

```hcl
db_password_version = 2
```

The plan generated on `main` then shows three changes:

- A new version of the `wordpress-db-password` secret, with a newly generated password.
- The Cloud SQL user updated with that password.
- The instance template replaced, because the version number is part of the instance metadata. The MIG replaces the instances, and the new ones read the new password at boot.

If the plan replaces the secret version, the apply reports it as a destructive change and needs `_ALLOW_DESTRUCTIVE=true` after reviewing it.

This is not a zero-downtime rotation: between the moment the password changes in Cloud SQL and the moment an instance is replaced, that instance cannot connect to the database. Avoiding that takes two passwords valid at the same time, which this project does not implement.

### Update the WordPress image

1. Modify provisioning scripts in `packer/scripts/`
2. Merge to `main` — the `packer-build` trigger fires automatically and registers a new image under the `wordpress-golden` family (about 5 minutes; 4 min 22 s measured on 2026-10-11)
3. When the build has finished, generate a plan. A change in `packer/**` alone does not trigger one:

   ```bash
   gcloud builds triggers run terraform-plan-main \
     --project=$PROJECT_ID \
     --branch=main
   ```

   The plan shows the instance template being replaced with the new image.
4. Apply that plan with `terraform-apply` — the MIG rolling update replaces the instances. An instance template replacement does not need `_ALLOW_DESTRUCTIVE=true`

---

## Modules

| Module | Description |
|---|---|
| `modules/networking` | VPC network, subnet, IAP SSH firewall rule, Cloud Router, Cloud NAT. All feature flags (`enable_nat`, `allow_ssh_from_iap`) are passed by the caller with no module-level defaults. |
| `modules/mig` | Instance template (Packer golden image), Regional MIG with distribution policy, global health check for auto-healing, and regional autoscaler with scale-in controls. |
| `modules/global_external_lb` | Global external Application Load Balancer: IP address (created or reserved beforehand), Google-managed SSL certificate, SSL policy, HTTPS forwarding rule, HTTP forwarding rule that redirects to HTTPS, backend service wired to the MIG, health check, and the firewall rule that lets the Google front ends reach the backends. |
| `modules/cloud_scheduler` | Cloud Scheduler job with OIDC-authenticated HTTP target, configurable retry policy, and cron schedule. Reused for both export and snapshot backup jobs. |

---

## Security Highlights

- No VM has a public IP address
- HTTPS only: Google-managed certificate, HTTP redirected to HTTPS, TLS 1.2 minimum
- Backends accept traffic only from the Google front end ranges, not from the internet
- Cloud SQL is accessible only via private IP within the VPC
- SSH access exclusively through IAP (no open port 22 to the internet)
- Database credentials stored in Secret Manager. The password is never in the repository, the Terraform state or a saved plan; on an instance it exists only in `wp-config.php`, written at boot by the startup script
- `project_id` and the operator email are not written in the code or the configuration — they are passed as Cloud Build substitutions (`TF_VAR_project_id`, `TF_VAR_iap_user_email`), so the repository deploys to any project without being edited. The project ID is an identifier, not a credential, and appears in the screenshots below
- Cloud SQL instance has `deletion_protection` and `prevent_destroy` set to `false` for portfolio teardown convenience (set to `true` in production)
- One service account per workload (management VM, WordPress instances, backup function runtime and build, scheduler), none with keys. Some roles are still broader than needed (see [Known Limitations](#known-limitations))
- Instances reach the statics bucket with their own service account, scoped to that bucket
- Secrets are readable by the WordPress instances one by one, not project-wide
- Custom IAM role for the backup function with only the required Cloud SQL permissions
- The destructive change check blocks the apply from destroying the database or the data buckets, even with `_ALLOW_DESTRUCTIVE=true`
- Every bucket has uniform bucket-level access and public access prevention enforced, set once in `locals.tf`

---

## Known Limitations

What the code does not do yet, tracked in [docs/to-do.md](docs/to-do.md):

- **Management VM without database access.** VPC peering is not transitive, so the management VM cannot reach the private IP of Cloud SQL through the production VPC; the Auth Proxy also runs without `--private-ip`, its service account cannot read the secret it fetches, and the VM boots from the WordPress image. The Auth Proxy download is pinned to a version but not verified with a checksum.
- **Snapshot backups have no retention.** The on-demand backups taken every 4 hours are never deleted.
- **IAM is not fully least-privilege.** The management VM has `roles/cloudsql.editor` on the project, and the Cloud SQL service account has `roles/storage.admin` on the backup bucket where writing objects would be enough.
- **A single instance at rest** (`min_replicas = 1`): no zone-level fault tolerance, see [Regional MIG](#regional-mig-over-unmanaged-instance-group).
- **WordPress version not pinned.** The image build downloads the latest release from wordpress.org without a checksum.
- **The password rotation is not zero-downtime**, see [Rotate the database password](#rotate-the-database-password).

---

## Screenshots

Taken from a deploy from scratch of this repository.

### CI/CD

**Cloud Build — Triggers.** The four triggers created by `configs/setup.sh`.

![Cloud Build triggers](docs/screenshots/gcb-triggers.png)

**Cloud Build — Plan and apply.** A plan generated on `main` by `terraform-plan-main`, the apply of that plan by `terraform-apply`, and the build of the backup function that the apply starts in `europe-west1`.

![Cloud Build history with a successful plan and apply](docs/screenshots/plan-apply-success.png)

### Compute

**Compute Engine — VM instances.** The management VM and a WordPress instance of the MIG. Neither has an external IP.

![VM instances](docs/screenshots/vm-instances.png)

**Load balancer — Healthy backend.** The MIG as backend of the load balancer. An instance counts as healthy only after its startup script has finished configuring it.

![Healthy backend](docs/screenshots/healthy-backend.png)

### Data

**Cloud SQL — Instance.**

![Cloud SQL instance](docs/screenshots/cloudsql-instance.png)

**Secret Manager — Secrets.**

![Secret Manager secrets](docs/screenshots/secrets.png)

**Cloud Scheduler — Backup jobs.** The export and snapshot jobs after a successful run.

![Cloud Scheduler backup jobs](docs/screenshots/scheduler-jobs-success.png)

**Cloud Storage — Uploads in the statics bucket.** A file uploaded from WordPress, stored under `uploads/` in the bucket that every instance mounts with Cloud Storage FUSE.

![Uploaded file in the statics bucket](docs/screenshots/static-objects-upload.png)

### HTTPS

**HTTP redirects to HTTPS.** A request on port 80 is answered with a 301 to the HTTPS URL.

![HTTP to HTTPS redirect](docs/screenshots/https-redirection.png)

**TLS 1.1 is rejected.** The SSL policy of the load balancer accepts TLS 1.2 and later only.

![TLS 1.1 rejected](docs/screenshots/old-tls-versions-forbidden.png)

### WordPress

**Setup over HTTPS.** The installer under `/wp-admin`, served on the domain through the load balancer with the managed certificate.

![WordPress setup](docs/screenshots/wordpress-setup.png)

**Online via the load balancer.**

![WordPress online](docs/screenshots/wordpress-hello-world.png)

---

## Roadmap

Features not implemented in this version but planned as natural next steps:

- **Cloud Monitoring & Alerting** — uptime checks on the load balancer IP, alert policies for Apache error rate and instance health, Cloud Ops Agent for OS-level and Apache metrics (requests/s, latency, error rate)
- **Cloud Armor** — WAF rules and DDoS protection in front of the load balancer
- **Cloud CDN** — enable caching at the load balancer level for static WordPress assets
- **Terraform tests** — infrastructure validation using `terraform test` or Terratest
- **Multi-region failover** — add a Cloud SQL cross-region replica that can be promoted, and a second MIG in another region behind the same global load balancer
- **Uploads served from the bucket** — a backend bucket on the load balancer, so media no longer goes through the instances
