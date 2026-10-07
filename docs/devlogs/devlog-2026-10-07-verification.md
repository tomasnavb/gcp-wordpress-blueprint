# Devlog — Verification deploy

Checklist for the first deploy from scratch after the fixes in [devlog-2026-10-07.md](devlog-2026-10-07.md). It confirms tasks 1 to 9, which are fixed in code and marked `unverified` there.

Follow the README step by step on a new project. Fill in **Result** as you go and write the exact error text under [Errors found](#errors-found).

| Result | Meaning |
|---|---|
| `pending` | Not reached yet |
| `done` | Worked as described |
| `failed` | Did not work; see the error entry |
| `skipped` | Not run; say why |

**Project:** _fill in_ · **Date:** _fill in_ · **Branch / commit:** _fill in_

## Before starting

| # | Check | Result |
|---|---|---|
| 0.1 | New project with billing enabled | `pending` |
| 0.2 | Google Cloud Build app removed from GitHub for the deleted projects, repository connected to the new project | `pending` |
| 0.3 | Deployment variables exported in the shell (`PROJECT_ID`, `REPO_NAME`, `REPO_OWNER`, `IAP_USER_EMAIL`) | `pending` |

## Phase A — First deploy, manual builds from the branch

The README commands upload the local checkout, so nothing has to be merged yet. Fix on the branch and retry.

| # | Check | Task | Result |
|---|---|---|---|
| A1 | `setup.sh` finishes on a project where no API was enabled by hand | 1 | `pending` |
| A2 | `setup.sh` stops with a clear error if a variable is not exported | 5 | `pending` |
| A3 | `setup.sh` reserves the load balancer IP and prints it | LB | `pending` |
| A4 | Four triggers exist: `packer-build`, `terraform-plan-pr`, `terraform-plan-main`, `terraform-apply` | 4 | `pending` |
| A5 | DNS A record created; `nslookup` returns the reserved IP | LB | `pending` |
| A6 | Packer build, step `install-packer`: download, checksum `OK`, `packer version` prints 1.16.1 | 6 | `pending` |
| A7 | Packer build with `_USE_IAP=false` in the `default` network produces an image in the `wordpress-golden` family | 6 | `pending` |
| A8 | Packer verification step: `php -l` reports no syntax errors in `wp-config.php` and the proxy block is found | 8 | `pending` |
| A9 | Plan build: the email validation passes and both data sources resolve (golden image, reserved IP) | 5, 6, LB | `pending` |
| A10 | Plan build: step `report-destructive-changes` prints "No destructive changes detected" and the artifacts are uploaded | 4 | `pending` |
| A11 | Apply build: step `enforce-destructive-changes` passes | 4 | `pending` |
| A12 | Apply build: the Cloud Function builds. The Compute Engine default SA has no role granted by hand | 2 | `pending` |
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

_None yet._
