# To-do

Single list of the project's tasks and their status. It replaces the task tables of the devlogs, which stay as the record of what happened: symptoms, causes, fixes and decisions.

- **Created** is the date the task was written down.
- **Detail** points to where the task is explained. "Backlog" is [devlog-2026-10-07.md](devlogs/devlog-2026-10-07.md), "Devlog 10-08" is [devlog-2026-10-08.md](devlogs/devlog-2026-10-08.md), "Verification" is [devlog-2026-10-07-verification.md](devlogs/devlog-2026-10-07-verification.md). The number is the task or entry there.

| Status | Meaning |
|---|---|
| `pending` | Not started |
| `in-progress` | Being worked on |
| `unverified` | In the code, not yet confirmed in a real deploy |
| `done` | Confirmed in a real deploy, or finished if it needs no deploy |
| `dropped` | Decided not to do |

Last updated: 2026-10-18.

## Open

In priority order.

### 0. Refactor: naming convention, network and pipeline identities

Applies the naming convention of the architecture style guide (`[project]-[component]-[environment]`, short project name `wp-blueprint`, region only in subnet names, service accounts without environment), removes the management VPC (T31), adds a dedicated subnet for the image build, splits the pipeline service account (T35), and adds the edge layer: uploads served from a backend bucket, Cloud CDN and Cloud Armor (T24, T42). Done on a clean deploy: nothing is deployed while it is in progress. Task IDs `R..` belong to this block.

| ID | Task | Created | Status | Detail |
|---|---|---|---|---|
| R01 | Variable `environment` (validated to `dev` or `prod`) and local `name_prefix = "wp-blueprint"`; every resource name built in `locals.tf`. Remove the per-resource name variables from `variables_*.tf` and `terraform.tfvars` | 2026-10-16 | `unverified` | Naming review of 2026-10-16 |
| R02 | Replace the local `networking` module with the official Google modules, pinned to exact versions: `terraform-google-modules/network/google` (VPC, subnets, firewall rules) and `terraform-google-modules/cloud-router/google` (Cloud Router and Cloud NAT). Delete `terraform/modules/networking` | 2026-10-16 | `unverified` | Naming review of 2026-10-16 |
| R03 | Rename networking: `wp-blueprint-vpc-prod`, `web-subnet-prod-europe-west1`, `wp-blueprint-router-prod`, `wp-blueprint-nat-prod`, `wp-blueprint-allow-iap-ssh-prod`, `wp-blueprint-psa-range-prod` | 2026-10-16 | `unverified` | Naming review of 2026-10-16 |
| R04 | Rename compute: template prefix `wp-blueprint-web-tpl-prod-`, `wp-blueprint-web-mig-prod`, instances `wp-blueprint-web-prod`, `wp-blueprint-web-autoscaler-prod`, `wp-blueprint-web-hc-prod` | 2026-10-16 | `unverified` | Naming review of 2026-10-16 |
| R05 | Rename the load balancer: remove the `-global-external-lb` suffix from the module, every name `wp-blueprint-lb-*-prod` (IP `wp-blueprint-lb-ip-prod`, also in `configs/setup.sh`), firewall `wp-blueprint-allow-google-fe-prod` | 2026-10-16 | `unverified` | Naming review of 2026-10-16 |
| R06 | Rename data: `wp-blueprint-db-prod`, secrets `wp-blueprint-db-{name,user,password,host,connection}-prod`, buckets `<project_id>-uploads` (see R23), `<project_id>-db-backups`, `<project_id>-fn-source`, function `wp-blueprint-db-backup-fn-prod`, job `wp-blueprint-db-export-job-prod`, custom role `wpBlueprintDbBackup` | 2026-10-16 | `unverified` | Naming review of 2026-10-16 |
| R07 | Rename workload service accounts: `web-vm-sa`, `db-backup-fn-sa`, `db-backup-build-sa`, `scheduler-invoker-sa` | 2026-10-16 | `unverified` | Naming review of 2026-10-16 |
| R08 | Image: family `wp-blueprint-web`, image `wp-blueprint-web-{{timestamp}}`, in the Packer template and the image data source | 2026-10-16 | `unverified` | Naming review of 2026-10-16 |
| R09 | State: bucket `<project_id>-tfstate` and backend prefix `wp-blueprint/prod`, in `configs/setup.sh`, both Terraform pipelines and the README | 2026-10-16 | `unverified` | Naming review of 2026-10-16 |
| R10 | Triggers: `wp-blueprint-image-build-prod`, `wp-blueprint-tf-plan-pr-prod`, `wp-blueprint-tf-plan-main-prod`, `wp-blueprint-tf-apply-prod`, in `configs/setup.sh` and the README commands | 2026-10-16 | `unverified` | Naming review of 2026-10-16 |
| R11 | Remove the management VPC (T31): its network, both peerings, the management VM, `mgmt-vm-sa` and its bindings, `startup-mgmt.sh`, the management variables and `local.service_accounts.mgmt` | 2026-10-16 | `in-progress` | Production review of 2026-10-14, T31 |
| R12 | Build subnet `build-subnet-prod-europe-west1` (`/28`) in the production VPC, only for the ephemeral Packer VM | 2026-10-16 | `unverified` | Naming review of 2026-10-16 |
| R13 | Build firewall rules: SSH through IAP only to the tag `packer-build`, and egress from the build subnet to the Private Service Access range denied, so the build VM cannot reach Cloud SQL. Packer uses that tag instead of `iap-ssh-access`, which the web instances keep | 2026-10-16 | `in-progress` | Naming review of 2026-10-16 |
| R14 | The first image build keeps running in the `default` network with an external IP (`_USE_IAP=false`), as today, because the production VPC does not exist before the first apply. Later builds run through IAP in the build subnet. New script in `configs/` that deletes the `default` network and its firewall rules after the first apply (optional step, documented in the README; afterwards `_USE_IAP=false` no longer works in that project). A separate network root with its own state, which would remove this exception, is left for T38 | 2026-10-16 | `pending` | Naming review of 2026-10-16 |
| R15 | Pipeline service accounts (T35): `terraform-plan-sa` (read-only, both plan triggers; check what the ephemeral password read needs during plan), `terraform-apply-sa` (write roles, apply only), `packer-build-sa` (image build). Created by `configs/setup.sh`, one per trigger | 2026-10-16 | `pending` | Production review of 2026-10-14, T35 |
| R16 | `configs/destroy.sh` with the new bucket and VPC names | 2026-10-16 | `unverified` | Naming review of 2026-10-16 |
| R17 | Secret names in `terraform/scripts/startup-prod.sh` | 2026-10-16 | `unverified` | Naming review of 2026-10-16 |
| R18 | Check `cloudbuild/scripts/check_destructive.py`: it uses Terraform addresses, so it only changes if a protected address is renamed | 2026-10-16 | `unverified` | Naming review of 2026-10-16 |
| R19 | README: new names, Configuration tables (`environment` instead of the name variables), Project Structure, commands, and every section about the management VPC | 2026-10-16 | `pending` | Naming review of 2026-10-16 |
| R20 | Architecture diagram PNG in the README with the caption about the build subnet; remove `architecture.jpeg` and its outdated note. Fix in the diagram first: `MySQL :3309` to `:3306`, `/upoads` to `/uploads` | 2026-10-16 | `in-progress` | Naming review of 2026-10-16 |
| R21 | Regenerate the README of every local module that changes, with terraform-docs | 2026-10-16 | `in-progress` | Naming review of 2026-10-16 |
| R23 | Uploads bucket: `<project_id>-uploads` replaces the statics bucket and holds only the uploads, in the folder `wp-content/uploads` (`local.statics_uploads_folder`), so the object path equals the URL path and the backend bucket needs no URL rewrite. Anything private, such as plugins (T22), goes in a separate bucket | 2026-10-16 | `unverified` | Edge review of 2026-10-16 |
| R24 | Backend bucket for `/wp-content/uploads/*` (path rule in the URL map). First check whether Cloud CDN can read a private bucket, which keeps `public_access_prevention` enforced; if not, grant `allUsers` `roles/storage.legacyObjectReader` (read a known object, no listing) and document the exception to the shared bucket local. Replaces T24 | 2026-10-16 | `pending` | Edge review of 2026-10-16, T24 |
| R25 | Cloud CDN on the backend service and on the backend bucket, both with `cache_mode = "CACHE_ALL_STATIC"`. Comment in the code why `FORCE_CACHE_ALL` is ruled out (it would cache pages of logged-in users) | 2026-10-16 | `pending` | Edge review of 2026-10-16 |
| R26 | Cloud Armor: backend security policy on the backend service with the preconfigured OWASP rules and rate limiting on `wp-login.php` and `xmlrpc.php`; edge security policy on the backend bucket if needed. Replaces T42 | 2026-10-16 | `pending` | Edge review of 2026-10-16, T42 |
| R27 | README note: uploads are public by design, as in standard WordPress; per-user private files would go in a separate private bucket served through signed URLs, never in the uploads bucket | 2026-10-16 | `pending` | Edge review of 2026-10-16 |
| R22 | Verification: `fmt`, `validate` and `tflint`, then a deploy from scratch. Checks: names in the console, first and later builds through IAP in the build subnet, the build VM cannot reach Cloud SQL, uploads served by the backend bucket, CDN cache hits on uploads and on theme assets but not on HTML or logged-in pages, Cloud Armor rules blocking a test request, the checks of T10, and the open checks of T01 and T03 to T06 | 2026-10-16 | `pending` | Naming review of 2026-10-16 |

### 1. Finish verifying what is already deployed

| ID | Task | Created | Status | Detail |
|---|---|---|---|---|
| T01 | Run the deploy checks not run yet: A2 (`setup.sh` stops without its variables), A5 (`nslookup`), A10 ("No destructive changes detected"), A16 (no logging denial on a fresh production instance), B6 (a destroy listed by the plan). Confirmed on 2026-10-11: A14 (both scheduler jobs), A20 (HTTP redirects to HTTPS) and A21 (TLS 1.1 rejected) | 2026-10-08 | `in-progress` | Verification, phases A and B |
| T02 | Management VM writes its logs to Cloud Logging (`roles/logging.logWriter`) | 2026-10-07 | `dropped` | Backlog 3, check A15; management VM removed (R11) |
| T03 | The apply pipeline prints the outputs: load balancer IP, site URLs, certificate name | 2026-10-07 | `unverified` | Backlog 7, check A13 |
| T04 | An instance whose startup script fails is reported unhealthy and replaced | 2026-10-08 | `pending` | Verification E3 |
| T05 | The admin panel cannot install or edit plugins and themes (`DISALLOW_FILE_MODS`) | 2026-10-08 | `unverified` | Devlog 10-08, 21 |
| T06 | A rollout that replaces the function source zip passes without `_ALLOW_DESTRUCTIVE` | 2026-10-08 | `unverified` | Verification E4 |
| T07 | Destroy procedure with `configs/destroy.sh` works as the README describes | 2026-10-08 | `unverified` | Verification E5 |
| T08 | Correct the 10–15 minutes stated for the image build in the README and `cloudbuild/packer.yaml`. Measured: 4 min 22 s for the whole build from the trigger on 2026-10-11 (3 min 26 s for the first manual build on 2026-10-07) | 2026-10-08 | `in-progress` | Verification, build log notes |
| T09 | New screenshots (console in English; hidden: project number, emails, WordPress admin username, secret values; the project ID may show) and updated architecture diagram; then fix the image references in the README | 2026-10-08 | `in-progress` | Devlog 10-08, 7 |

### 2. Secrets

| ID | Task | Created | Status | Detail |
|---|---|---|---|---|
| T10 | Database password out of the Terraform state and the saved plans, with ephemeral resources and write-only arguments. Implemented on 2026-10-11 with Secret Manager as the source of truth; to confirm on a clean deploy: the same value reaches the secret and the SQL user, the ephemeral read waits for the secret on the first apply, the state and a saved plan do not contain the password, and a rotation replaces the instances | 2026-10-09 | `unverified` | Devlog 10-08, priority 3 |
| T11 | WordPress keys and salts defined in `wp-config.php` from Secret Manager, with the same pattern as T10 | 2026-10-08 | `pending` | Devlog 10-08, 22 |

### 3. What the README claims and the code does not do

| ID | Task | Created | Status | Detail |
|---|---|---|---|---|
| T12 | Management VM cannot reach Cloud SQL: peering is not transitive, the Auth Proxy lacks `--private-ip`, its SA cannot read the secret it fetches, and it boots from the WordPress image. Includes verifying the Auth Proxy download with a checksum | 2026-10-07 | `dropped` | Backlog 10; management VM removed (R11, T31) |
| T13 | Snapshot backups have no retention | 2026-10-07 | `dropped` | Backlog 12; snapshot backups removed (T32) |
| T14 | Tighten IAM to match the least-privilege claim | 2026-10-07 | `pending` | Backlog 13 |

### 4. Follow-ups on code already merged

| ID | Task | Created | Status | Detail |
|---|---|---|---|---|
| T15 | Decide whether to fix the file permissions inside the function zip (`output_file_mode = "0644"`), so it does not change between a local and a trigger build | 2026-10-08 | `pending` | Verification E4 |
| T16 | Find out whether the function build SA needs `storage.objectViewer` on the scripts bucket; if not, remove the binding | 2026-10-08 | `pending` | Verification E2 |
| T17 | Terraform style guide review: modules without `required_version` and `required_providers`, two resource names with hyphens, two module outputs without description, a misplaced `lifecycle` block, inconsistent file names. Decide which to fix | 2026-10-11 | `pending` | Review of 2026-10-11, not in a devlog yet |

### 5. Missing pieces

| ID | Task | Created | Status | Detail |
|---|---|---|---|---|
| T18 | Observability: Ops Agent, uptime check, alert policy | 2026-10-07 | `pending` | Backlog 14 |
| T19 | Static analysis in the plan pipeline (tflint, checkov) | 2026-10-07 | `pending` | Backlog 15 |
| T20 | Pin the WordPress version and verify its checksum in the image build | 2026-10-07 | `pending` | Backlog 17 |

### 6. Improvements

| ID | Task | Created | Status | Detail |
|---|---|---|---|---|
| T21 | First deploy through the triggers, from `main`, instead of `gcloud builds submit` with the local clone | 2026-10-08 | `pending` | Devlog 10-08, 18 |
| T22 | Decide how plugins and themes are managed; if they move out of the image, a separate private bucket mounted on the instances, never the public uploads bucket (R23) | 2026-10-11 | `pending` | Devlog 10-08, 24 |
| T23 | Let `packer-build` trigger the Terraform plan when it finishes, instead of running it by hand | 2026-10-07 | `pending` | Backlog 6, "Later improvement" |
| T24 | Serve uploads straight from the bucket through a backend bucket on the load balancer | 2026-10-08 | `pending` | Devlog 10-08, priority 2; implemented in R24 |
| T25 | Clean up old golden images, which accumulate with every build | 2026-10-09 | `pending` | — |

### 7. Minor

| ID | Task | Created | Status | Detail |
|---|---|---|---|---|
| T26 | Silence the `debconf` warnings of the image build (`DEBIAN_FRONTEND=noninteractive`) | 2026-10-08 | `pending` | Verification, build log notes |
| T28 | Remaining cleanup: the note in `APIs.tf` about PostgreSQL, MongoDB and a VPC connector, the unused `vpcaccess` API, and `min_replicas = 1` against the zone fault tolerance claim | 2026-10-07 | `in-progress` | Backlog 16 |
| T29 | Delete merged and stray branches: `update/https-lb-fr`, `update/global-https-lb-and-pipeline`, `fix/destroy-service-networking`, `feature/stateless-wordpress`, local branch `origin` | 2026-10-08 | `pending` | Devlog 10-08, 16 |
| T30 | Mark A18 and A19 in the verification checklist: WordPress over HTTPS with its styles, and `/wp-admin` without a redirect loop | 2026-10-08 | `pending` | Verification A18, A19 |

### 8. Production readiness

Changes to take the project from a portfolio deployment to one configured and documented as production. In priority order. Open tasks above that are also part of this: T11 (keys and salts), T14 (least-privilege IAM), T18 (observability), T19 (static analysis), T20 (pinned WordPress), T23 (image build triggers the plan), T25 (old images).

| ID | Task | Created | Status | Detail |
|---|---|---|---|---|
| T31 | Remove the management VPC, the peering and the management VM. Packer builds in a subnet of the production VPC; admin access to the database through an IAP tunnel to a production instance or an admin VM created on demand. Replaces T12 | 2026-10-14 | `in-progress` | Production review of 2026-10-14; implemented in R11 |
| T32 | Remove the snapshot backups from the function and the scheduler, and configure point-in-time recovery explicitly (`retained_backups`, `transaction_log_retention_days`, backup window). The daily export stays. Replaces T13 | 2026-10-14 | `in-progress` | Production review of 2026-10-14 |
| T33 | Restore runbook, tested: point-in-time recovery to a new instance, and restore from an export | 2026-10-14 | `pending` | Production review of 2026-10-14 |
| T34 | Database protection: `deletion_protection` and `prevent_destroy` set to `true`, and the destroy procedure documented (a reviewed change that turns protection off first) | 2026-10-14 | `pending` | Production review of 2026-10-14 |
| T35 | Separate pipeline service accounts: read-only for pull request plans, which can run code from the PR, and the account with write roles for the apply only | 2026-10-14 | `pending` | Production review of 2026-10-14; implemented in R15 |
| T36 | Production values: `min_replicas` of at least 2 (zone fault tolerance), Cloud SQL tier sized, maintenance window, Query Insights | 2026-10-14 | `pending` | Production review of 2026-10-14 |
| T37 | Alerting that reaches someone: notification channel for the T18 alerts, export failure alert, and a billing budget alert | 2026-10-14 | `pending` | Production review of 2026-10-14 |
| T38 | Staging environment: a separate project with the same code, its own variable file and its own state. Includes renaming `terraform.tfvars` per environment | 2026-10-14 | `pending` | Production review of 2026-10-14 |
| T39 | SMTP relay for WordPress mail (port 25 is blocked on Compute Engine), with its credential in Secret Manager | 2026-10-14 | `pending` | Production review of 2026-10-14 |
| T40 | Operating system patching: scheduled image rebuild or VM Manager, and rollback to the previous image documented | 2026-10-14 | `pending` | Production review of 2026-10-14 |
| T41 | Shielded VM and enforced OS Login on the instances | 2026-10-14 | `pending` | Production review of 2026-10-14 |
| T42 | Cloud Armor: OWASP rules, and rate limiting on `wp-login.php` and `xmlrpc.php` | 2026-10-14 | `pending` | Production review of 2026-10-14; implemented in R26 |
| T43 | README: monthly cost estimate, and portfolio notes removed once the values are production ones | 2026-10-14 | `pending` | Production review of 2026-10-14 |
| T44 | Optional, only if justified: a cross-region Cloud SQL replica for disaster recovery, Memorystore as object cache if measurements call for it, an edge security policy on the uploads backend bucket with a rate limit per IP if mass downloading or egress cost calls for it (devlog 2026-10-25) | 2026-10-14 | `pending` | Production review of 2026-10-14 |

## Done

| ID | Task | Created | Closed | Detail |
|---|---|---|---|---|
| D01 | Bootstrap APIs enabled by `setup.sh`, and Service Usage admin for the pipeline SA | 2026-10-07 | 2026-10-07 | Backlog 1, check A1 |
| D02 | Dedicated build service account for the backup function, reading `gcf-v2-sources` through a conditional binding, after an IAM propagation wait | 2026-10-07 | 2026-10-08 | Backlog 2, Verification E1 and E2 |
| D03 | Destructive change gate enforced at apply, and plan generated on `main` | 2026-10-07 | 2026-10-08 | Backlog 4, checks B7 and B8 |
| D04 | Operator email passed as a pipeline substitution and validated at plan time | 2026-10-07 | 2026-10-08 | Backlog 5 |
| D05 | Image built through IAP from the trigger, and new images rolled out to the MIG | 2026-10-07 | 2026-10-08 | Backlog 6, checks B3 to B5 |
| D06 | WordPress aware of HTTPS behind the load balancer (`X-Forwarded-Proto`) | 2026-10-07 | 2026-10-08 | Backlog 8 |
| D07 | README and module READMEs describe the global HTTPS load balancer. Screenshots and diagram continue in T09 | 2026-10-07 | 2026-10-08 | Backlog 9 |
| D08 | Global HTTPS load balancer: port 80 redirect, managed certificate, TLS 1.2 policy, reserved IP | 2026-10-07 | 2026-10-08 | Backlog, priority 1 |
| D09 | Instances do not serve traffic until they are configured: MIG ordered after its dependencies, readiness marker in the health check | 2026-10-07 | 2026-10-08 | Verification E3 |
| D10 | `deletion_policy = "ABANDON"` on the Cloud SQL network connection: the destroy finishes without deleting the peering by hand | 2026-10-08 | 2026-10-09 | Verification E5 |
| D11 | Deploy from scratch from `main` through the triggers, with the fixes of the first deploy confirmed in a clean run | 2026-10-08 | 2026-10-11 | Devlog 10-08, 1 and 2 |
| D12 | Research how Cloud Storage FUSE works before implementing | 2026-10-08 | 2026-10-09 | Devlog 10-08, 19 |
| D13 | Uploads in the statics bucket, mounted on the instances with Cloud Storage FUSE. Confirmed: the image build installs `gcsfuse`, the instances are healthy, an uploaded file is stored under `uploads/` in the bucket and is still served by a new instance after a rolling replace | 2026-10-08 | 2026-10-11 | Devlog 10-08, 20 |
| D14 | Bucket renamed to `wordpress-statics-<project_id>` with a fixed name, and an `uploads/` folder created by Terraform and passed to the instances as metadata | 2026-10-11 | 2026-10-11 | Devlog 10-08, 24 |
| D15 | Shared access settings for every bucket, defined once in locals | 2026-10-11 | 2026-10-11 | — |
| D16 | Fix the two misaligned lines reported by `packer fmt` in `wordpress.pkr.hcl` | 2026-10-07 | 2026-10-18 | Backlog 16; fixed by `packer fmt` in refactor block 3 |
