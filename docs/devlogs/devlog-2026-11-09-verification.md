# Verification — 2026-11-09

Checklist of the deploy from scratch that verifies the refactor (task R22 in [../to-do.md](../to-do.md)) and the block that followed the installer takeover (R28 to R32, T20, T32, the maintenance window of T36; see [devlog-2026-10-30.md](devlog-2026-10-30.md)). It replaces the checks of [devlog-2026-10-26-verification.md](devlog-2026-10-26-verification.md), which were left `pending` when that deploy was destroyed after E4. The deploy runs from the branch `refactor/naming-and-network` with `gcloud builds submit`, in a new project, before anything is merged to `main`.

How each test is run is in [../test-procedure.md](../test-procedure.md); this file records what this run found.

Result values: `pending`, `done`, `failed`, `skipped`. When a check passes, the matching task in the to-do is set to `done`.

## Phase A — Bootstrap and first deploy

| # | Check | Tasks | Result |
|---|---|---|---|
| A1 | `setup.sh` creates the state and source buckets, `gs://<project_id>_cloudbuild` with read access for `packer-build-sa` and `terraform-plan-sa`, the three pipeline service accounts with their roles, the four triggers and the reserved IP `wp-blueprint-lb-ip-prod` | R09, R10, R15 | `pending` |
| A2 | `setup.sh` stops before creating anything when a required variable is not exported | T01 | `pending` |
| A3 | `gcloud builds triggers describe` shows `_DOMAIN_NAMES` stored whole, with its commas, and `_IAP_USER_EMAIL` on both plan triggers | R30 | `pending` |
| A4 | `configs/org-policy-exception.sh` (Step 5b), only if the project is in an organization: the managed constraint with the `https-lb` service agent as exception, then the legacy constraint reset | E3 of 10-26 | `pending` |
| A5 | First image build in the `default` network (`_USE_IAP=false`) with `packer-build-sa`; image registered in the `wp-blueprint-web` family. The build verifies every download against `checksums.sha256` | R08, R14, T20 | `pending` |
| A6 | First plan with `terraform-plan-sa` | R15 | `pending` |
| A7 | First apply with `terraform-apply-sa`; the binding of the `https-lb` service agent on the uploads bucket is created without an error | R15, R24 | `pending` |
| A8 | The apply prints `load_balancer_ip`, `site_urls` and `ssl_certificate_name` | T03 | `pending` |
| A9 | Resource names in the console follow the naming convention (VPC, subnets, router, NAT, firewall rules, MIG, load balancer and both backend services, Cloud SQL, secrets, buckets, function, job, service accounts) | R01–R07 | `pending` |
| A10 | DNS resolves to the load balancer IP (`nslookup`) and the certificate is `ACTIVE` | T01 | `pending` |
| A11 | Two instances, in two zones, both healthy; the startup script reads every name from the metadata and gcsfuse mounts `wp-content/uploads` | R17, R23, R32 | `pending` |
| A12 | On an instance: `WP_HOME` and `WP_SITEURL` in `wp-config.php` with the first domain, WordPress 7.1.3 and the ten languages installed, and room on the disk (`df -h`) | R29, T20 | `pending` |
| A13 | No logging permission denial on a fresh instance | T01 | `pending` |

## Phase B — Edge security and installation

| # | Check | Tasks | Result |
|---|---|---|---|
| B1 | Smoke tests before the installation (`tests/smoke/edge-security.sh`, without upload path): all pass, with `/` and `admin-ajax.php` answering 302 to the installer | R28, R30 | `pending` |
| B2 | Manual check 1: the installer only through IAP; an account outside `iap_members` is refused | R30 | `pending` |
| B3 | Manual check 2: installation by the operator through IAP, in English | R30 | `pending` |
| B4 | Manual checks 3 to 8: site language list, no application passwords, no file changes from the admin panel, links with the site's domain, public site without sign-in, sign-out | R29, R31, T05 | `pending` |
| B5 | An image uploaded from WordPress is stored as `wp-content/uploads/...` in the uploads bucket and served by the backend bucket | R23, R24 | `pending` |
| B6 | Smoke tests after the installation, with the upload path: all pass, `admin-ajax.php` answering 400 with body `0` | R28, R30 | `pending` |
| B7 | The uploads bucket stays private: public access prevention enforced, and the object URL on `storage.googleapis.com` is denied | R24 | `pending` |
| B8 | Cloud CDN hits on uploads and on theme assets; none on HTML or the admin area | R25 | `pending` |
| B9 | More than 5 `POST /wp-login.php` per minute from one IP answer 429; over 50 in 10 minutes, the IP is banned. Note whether throttled requests count toward the ban | R26 | `pending` |
| B10 | The load balancer logs show the Cloud Armor rule of each denial (rules 50, 100, 150) and the WAF matches in preview (`jsonPayload.previewSecurityPolicy`) | R26 | `pending` |

## Phase C — Database

| # | Check | Tasks | Result |
|---|---|---|---|
| C1 | The database password is in neither the state nor the saved plan, and the secret and the SQL user hold the same value | T10 | `pending` |
| C2 | Backup configuration of the instance: binary logs on, 8 retained backups, 7 days of logs, window at 02:00 UTC | T32 | `pending` |
| C3 | Maintenance window of the instance: Sunday, 04:00 UTC, `stable` (`gcloud sql instances describe ... --format="yaml(settings.maintenanceWindow)"`) | T36 | `pending` |
| C4 | The export job runs and its file is in `<project_id>-db-backups/exports/` | — | `pending` |
| C5 | Failover (`tests/resilience/sql-failover.sh`): operation `DONE`, primary in the former standby zone, same private IP, site answering again. Record the downtime and the operation's `startTime` and `endTime` | — | `pending` |

## Phase D — Changes through the pipeline

| # | Check | Tasks | Result |
|---|---|---|---|
| D1 | A plan after the first apply passes with `terraform-plan-sa` (ephemeral read of the password and refresh of the bucket objects) | R15 | `pending` |
| D2 | Image build from the trigger: the build VM runs in the build subnet, without an external IP or a service account, reached through IAP | R12, R13 | `pending` |
| D3 | The build VM cannot reach Cloud SQL's private range | R13 | `pending` |
| D4 | A new image rolls out to the MIG without `_ALLOW_DESTRUCTIVE` | — | `pending` |
| D5 | A rollout that replaces the function source zip passes without `_ALLOW_DESTRUCTIVE` | T06 | `pending` |
| D6 | A plan with a destroy lists it as destructive; the apply rejects it without the flag | T01, R18 | `pending` |
| D7 | An instance whose startup script fails is reported unhealthy and replaced | T04 | `pending` |
| D8 | The plan and image build triggers on `main` start on their own, each with its own service account | R10, R15 | `pending` |
| D9 | `configs/delete-default-network.sh` removes the default network and its firewall rules | R14 | `pending` |

## Phase F — Teardown

| # | Check | Tasks | Result |
|---|---|---|---|
| F1 | `configs/destroy.sh empty-buckets` empties the backup and uploads buckets | R16, T07 | `pending` |
| F2 | `terraform destroy` finishes | T07 | `pending` |
| F3 | The reserved IP is released | T07 | `pending` |

## Errors found

None yet.
