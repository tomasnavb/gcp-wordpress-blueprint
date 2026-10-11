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

Last updated: 2026-10-11.

## Open

In priority order.

### 1. Finish verifying what is already deployed

| ID | Task | Created | Status | Detail |
|---|---|---|---|---|
| T01 | Run the deploy checks not run yet: A2 (`setup.sh` stops without its variables), A5 (`nslookup`), A10 ("No destructive changes detected"), A16 (no logging denial on a fresh production instance), B6 (a destroy listed by the plan). Confirmed on 2026-10-11: A14 (both scheduler jobs), A20 (HTTP redirects to HTTPS) and A21 (TLS 1.1 rejected) | 2026-10-08 | `in-progress` | Verification, phases A and B |
| T02 | Management VM writes its logs to Cloud Logging (`roles/logging.logWriter`) | 2026-10-07 | `unverified` | Backlog 3, check A15 |
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
| T10 | Remove the database password from the Terraform state and the saved plans, with ephemeral resources and write-only arguments; rotate it afterwards | 2026-10-09 | `pending` | Devlog 10-08, priority 3 |
| T11 | WordPress keys and salts defined in `wp-config.php` from Secret Manager, with the same pattern as T10 | 2026-10-08 | `pending` | Devlog 10-08, 22 |

### 3. What the README claims and the code does not do

| ID | Task | Created | Status | Detail |
|---|---|---|---|---|
| T12 | Management VM cannot reach Cloud SQL: peering is not transitive, the Auth Proxy lacks `--private-ip`, its SA cannot read the secret it fetches, and it boots from the WordPress image. Includes verifying the Auth Proxy download with a checksum | 2026-10-07 | `pending` | Backlog 10 |
| T13 | Snapshot backups have no retention | 2026-10-07 | `pending` | Backlog 12 |
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
| T22 | Statics bucket: add a `plugins/` folder mounted on the instances, and decide how plugins and themes are managed | 2026-10-11 | `pending` | Devlog 10-08, 24 |
| T23 | Let `packer-build` trigger the Terraform plan when it finishes, instead of running it by hand | 2026-10-07 | `pending` | Backlog 6, "Later improvement" |
| T24 | Serve uploads straight from the bucket through a backend bucket on the load balancer | 2026-10-08 | `pending` | Devlog 10-08, priority 2 |
| T25 | Clean up old golden images, which accumulate with every build | 2026-10-09 | `pending` | — |

### 7. Minor

| ID | Task | Created | Status | Detail |
|---|---|---|---|---|
| T26 | Silence the `debconf` warnings of the image build (`DEBIAN_FRONTEND=noninteractive`) | 2026-10-08 | `pending` | Verification, build log notes |
| T27 | Fix the two misaligned lines reported by `packer fmt` in `wordpress.pkr.hcl` | 2026-10-07 | `pending` | Backlog 16 |
| T28 | Remaining cleanup: the note in `APIs.tf` about PostgreSQL, MongoDB and a VPC connector, the unused `vpcaccess` API, and `min_replicas = 1` against the zone fault tolerance claim | 2026-10-07 | `pending` | Backlog 16 |
| T29 | Delete merged and stray branches: `update/https-lb-fr`, `update/global-https-lb-and-pipeline`, `fix/destroy-service-networking`, `feature/stateless-wordpress`, local branch `origin` | 2026-10-08 | `pending` | Devlog 10-08, 16 |
| T30 | Mark A18 and A19 in the verification checklist: WordPress over HTTPS with its styles, and `/wp-admin` without a redirect loop | 2026-10-08 | `pending` | Verification A18, A19 |

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
