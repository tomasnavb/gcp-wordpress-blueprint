# Devlog — Verification deploy

Checklist for the first deploy from scratch after the fixes in [devlog-2026-10-07.md](devlog-2026-10-07.md). It confirms tasks 1 to 9, which are fixed in code and marked `unverified` there.

Follow the README step by step on a new project. Fill in **Result** as you go and write the exact error text under [Errors found](#errors-found).

| Result | Meaning |
|---|---|
| `pending` | Not reached yet |
| `done` | Worked as described |
| `failed` | Did not work; see the error entry |
| `skipped` | Not run; say why |

**Project:** `gcp-wordpress-blueprint-v2` · **Date:** 2026-10-07 · **Branch / commit:** `update/global-https-lb-and-pipeline` · _commit: fill in_

## Before starting

| # | Check | Result |
|---|---|---|
| 0.1 | New project with billing enabled | `done` |
| 0.2 | Google Cloud Build app removed from GitHub for the deleted projects, repository connected to the new project | `pending` |
| 0.3 | Deployment variables exported in the shell (`PROJECT_ID`, `REPO_NAME`, `REPO_OWNER`, `IAP_USER_EMAIL`) | `done` |

## Phase A — First deploy, manual builds from the branch

The README commands upload the local checkout, so nothing has to be merged yet. Fix on the branch and retry.

| # | Check | Task | Result |
|---|---|---|---|
| A1 | `setup.sh` finishes on a project where no API was enabled by hand | 1 | `done` |
| A2 | `setup.sh` stops with a clear error if a variable is not exported | 5 | `pending` |
| A3 | `setup.sh` reserves the load balancer IP and prints it | LB | `done` |
| A4 | Four triggers exist: `packer-build`, `terraform-plan-pr`, `terraform-plan-main`, `terraform-apply` | 4 | `done` |
| A5 | DNS A record created; `nslookup` returns the reserved IP | LB | `pending` |
| A6 | Packer build, step `install-packer`: download, checksum `OK`, `packer version` prints 1.16.1 | 6 | `done` |
| A7 | Packer build with `_USE_IAP=false` in the `default` network produces an image in the `wordpress-golden` family | 6 | `done` |
| A8 | Packer verification step: `php -l` reports no syntax errors in `wp-config.php` and the proxy block is found | 8 | `done` |
| A9 | Plan build: the email validation passes and both data sources resolve (golden image, reserved IP) | 5, 6, LB | `pending` |
| A10 | Plan build: step `report-destructive-changes` prints "No destructive changes detected" and the artifacts are uploaded | 4 | `pending` |
| A11 | Apply build: step `enforce-destructive-changes` passes | 4 | `pending` |
| A12 | Apply build: the Cloud Function builds. The Compute Engine default SA has no role granted by hand | 2 | `failed` |
| A13 | Apply build: the last step prints `load_balancer_ip`, `site_urls` and `ssl_certificate_name` | 7 | `pending` |
| A14 | Both scheduler jobs run successfully (`export-db-backup`, `snapshot-db-backup`) | 2 | `pending` |
| A15 | Management VM: startup script output appears in Cloud Logging | 3 | `pending` |
| A16 | Production VM: no `logging.logEntries.create` denial in its logs | 3 | `pending` |
| A17 | Certificate status is `ACTIVE` | LB | `pending` |
| A18 | `https://DOMAIN` loads WordPress with its styles | 8 | `pending` |
| A19 | `https://DOMAIN/wp-admin` opens the login page without a redirect loop | 8 | `pending` |
| A20 | `curl -I http://DOMAIN` answers `301` with a `Location: https://...` header | LB | `pending` |
| A21 | `curl --tlsv1.1 --tls-max 1.1 https://DOMAIN` is rejected | LB | `pending` |

### Useful commands

```bash
# A5
nslookup DOMAIN

# A14
gcloud scheduler jobs run export-db-backup   --location=europe-west1 --project=$PROJECT_ID
gcloud scheduler jobs run snapshot-db-backup --location=europe-west1 --project=$PROJECT_ID
gcloud sql backups list --instance=wordpress-prod-db --project=$PROJECT_ID
gcloud storage ls gs://wordpress-db-backups-$PROJECT_ID/exports/

# A12: roles of the Compute Engine default SA (expected: none added by hand)
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:compute@developer.gserviceaccount.com" \
  --format="value(bindings.role)"

# A15 / A16
gcloud logging read 'resource.type="gce_instance" AND protoPayload.status.message:"logging.logEntries.create"' \
  --project=$PROJECT_ID --freshness=2h --limit=5

# A17
gcloud compute ssl-certificates list --global --project=$PROJECT_ID
```

### Known before starting

- **The management VM startup script will fail.** It cannot read the secret it fetches and cannot reach Cloud SQL. That is task 10 of the backlog, not a regression. A15 only checks that its output reaches Cloud Logging.
- **`setup.sh` may fail on its first command outside Cloud Shell.** With `billing/quota_project` set in the local gcloud configuration to a project where the Service Usage API is disabled, `gcloud services enable` is rejected with `SERVICE_DISABLED`, even for enabling Service Usage itself. Cloud Shell does not have that setting. If it happens: enable the Service Usage API once from the console link in the error, or run `gcloud config unset billing/quota_project`, and record it here.
- **The certificate takes time.** From 15 minutes to over an hour after the DNS record resolves. A17 to A21 wait for it.

### Build log notes

**Packer build `fe5e4bba-38b3-4804-9672-f0b856b2c1a2`** (2026-10-07 20:17 UTC, manual submit). The log reviewed covers the `packer-build` step only, from the package installation onwards.

- A1, A3, A4: `setup.sh` finished without enabling any API by hand, printed the reserved IP and created the four triggers.
- A2: not exercised. The script was run with every variable exported.
- A5: the DNS A record was created. Resolution with `nslookup` still to be confirmed.
- A7: image `wordpress-golden-1791404089` created. The log ends with `Skipping cleanup of IAP tunnel; "iap" is false`, which confirms the direct SSH mode.
- A8: `No syntax errors detected in /var/www/html/wp-config.php`, and the verification script ended with exit code 0, so the `grep` for the proxy block matched.
- A6: confirmed from the `install-packer` step log: `/tmp/packer.zip: OK` and `Packer v1.16.1`.
- The `packer-build` step took 2 minutes 34 seconds. The README and `packer.yaml` say 10 to 15 minutes; adjust once a second build confirms it.
- `debconf: unable to initialize frontend` appears on every package: there is no terminal in the build. Harmless. `DEBIAN_FRONTEND=noninteractive` in `install.sh` would silence it.
- Lines in red starting with `+` are the `set -x` trace of `install.sh` on stderr, not errors.

## Phase B — Triggers

Run after phase A is complete.

| # | Check | Task | Result |
|---|---|---|---|
| B1 | Opening the pull request runs `terraform-plan-pr`; nothing is uploaded to the state bucket | 4 | `pending` |
| B2 | Merging runs `terraform-plan-main`; the plan is uploaded and shows no changes | 4 | `pending` |
| B3 | A merged change in `packer/**` runs `packer-build` with IAP; the build VM has no external IP | 6 | `pending` |
| B4 | `terraform-plan-main`, run by hand after B3, shows the instance template replacement | 6 | `pending` |
| B5 | `terraform-apply` accepts that plan without `_ALLOW_DESTRUCTIVE`; the MIG rolls to the new image | 4, 6 | `pending` |
| B6 | A merged change that destroys a resource (remove `vpcaccess.googleapis.com` from `APIs.tf`) is listed by the plan | 4 | `pending` |
| B7 | `terraform-apply` rejects that plan without the flag | 4 | `pending` |
| B8 | `terraform-apply` accepts the same plan with `_ALLOW_DESTRUCTIVE=true` | 4 | `pending` |

## Before tearing down

| # | Check | Result |
|---|---|---|
| C1 | New screenshots taken: triggers, a successful plan, VM instances, WordPress over HTTPS, scheduler jobs | `pending` |
| C2 | `terraform destroy` run locally | `pending` |
| C3 | The reserved IP still exists after the destroy | `pending` |
| C4 | Reserved IP released, if no further test session is planned | `pending` |
| C5 | Triggers deleted and repository disconnected, if the project is going to be deleted | `pending` |

## Errors found

One entry per error: the check number, the exact error text, the cause and the fix.

### E1 — A12: the function build cannot write logs

**Error.** First apply, on creating `google_cloudfunctions2_function.db_backup_fn`:

```
The service account cloudsql-backup-fn-build-sa@gcp-wordpress-blueprint-v2.iam.gserviceaccount.com does not have
permission to write logs. Ensure that the service account used for the build has the necessary permission
logging.logEntries.create(included in the "Log Writer" role).
```

**Cause (confirmed).** The retry got past this stage with no change to the binding, which was listed by `gcloud projects get-iam-policy`. The role is granted: `google_project_iam_member.fn_build_log_writer` gives `roles/logging.logWriter` to that service account, and the function depends on it. But IAM bindings take time to propagate, and the function build started seconds after the binding was created, in the same apply, when it was not effective yet. The other two bindings of the build SA have the same race.

**Fix.** `time_sleep.fn_build_iam_propagation` waits 120 seconds after the three bindings, and the function depends on that wait instead of on the bindings. Adds the `hashicorp/time` provider (0.14.2), recorded in the lock file for `linux_amd64` and `windows_amd64`.

**To confirm.**

- The binding exists (it should, from the failed apply):

  ```bash
  gcloud projects get-iam-policy $PROJECT_ID     --flatten="bindings[].members"     --filter="bindings.members:cloudsql-backup-fn-build-sa"     --format="value(bindings.role)"
  ```

- A new plan and apply creates the function. If the failed function was recorded as tainted, the plan shows it as a replace and the apply needs `_ALLOW_DESTRUCTIVE=true`.
- The real test of the wait is a deploy from scratch, where the bindings and the function are created in the same apply again.

### E2 — A12: the function build cannot read its source bucket

**Error.** Second apply, same resource:

```
Access to bucket gcf-v2-sources-979220652906-europe-west1 denied. You must grant Storage Object Viewer permission to
cloudsql-backup-fn-build-sa@gcp-wordpress-blueprint-v2.iam.gserviceaccount.com. If you are using VPC Service Controls,
you must also grant it access to your service perimeter.
```

**Cause.** A wrong assumption in the fix of task 2. The build SA was given `roles/storage.objectViewer` on the scripts bucket only, on the assumption that the build reads the zip from there. It does not: Cloud Functions copies the source to a bucket it creates itself, `gcf-v2-sources-<project number>-<region>`, and builds from that one. The manual workaround of 2026-10-06 (the role at project level on the default SA) covered that bucket; the scoped binding that replaced it did not.

The role did not show in `gcloud projects get-iam-policy` because a bucket-level binding is not part of the project policy.

**Fix.** `google_project_iam_member.fn_build_gcf_sources_viewer`: `roles/storage.objectViewer` at project level, because the bucket does not exist before the first deploy, with an IAM condition that limits it to buckets whose name starts with `gcf-v2-sources-`. Without the condition the build SA could read every bucket, including the database exports. The propagation wait of E1 covers this binding too.

**Risk.** IAM conditions on Cloud Storage only apply to buckets with uniform bucket-level access. If the bucket created by Cloud Functions does not have it, the conditional binding is ignored and the error repeats. Fallback: the same binding without the condition.

**Follow-up.** The binding on the scripts bucket (`fn_build_source_viewer`) is probably unnecessary. Remove it once a deploy confirms the build works, and check that a deploy without it still does.
