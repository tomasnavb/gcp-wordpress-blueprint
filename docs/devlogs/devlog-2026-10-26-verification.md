# Verification — 2026-10-26

Checklist of the deploy from scratch that verifies the refactor (task R22 in [../to-do.md](../to-do.md)). The deploy runs from the branch `refactor/naming-and-network` with `gcloud builds submit`, in a new project (`gcp-wordpress-test-deploy`), before anything is merged to `main`.

Result values: `pending`, `done`, `failed`, `skipped`. When a check passes, the matching task in the to-do is set to `done`.

## Phase A — Bootstrap and first deploy

| # | Check | Tasks | Result |
|---|---|---|---|
| A1 | `setup.sh` creates the state and source buckets, the three pipeline service accounts with their roles, the four triggers and the reserved IP `wp-blueprint-lb-ip-prod` | R09, R10, R15 | `pending` |
| A2 | `setup.sh` stops before creating anything when a required variable is not exported | T01 | `pending` |
| A3 | First image build in the `default` network (`_USE_IAP=false`) with `packer-build-sa`; image registered in the `wp-blueprint-web` family | R08, R14 | `pending` |
| A4 | First plan with `terraform-plan-sa` | R15 | `pending` |
| A5 | First apply with `terraform-apply-sa`; the binding of the `https-lb` service account on the uploads bucket is created without a "does not exist" error | R15, R24 | `pending` |
| A6 | The apply prints `load_balancer_ip`, `site_urls` and `ssl_certificate_name` | T03 | `pending` |
| A7 | Resource names in the console follow the naming convention (VPC, subnets, router, NAT, firewall rules, MIG, load balancer, Cloud SQL, secrets, buckets, function, job, service accounts) | R01–R07 | `pending` |
| A8 | DNS resolves to the load balancer IP (`nslookup`) and the certificate is `ACTIVE` | T01 (A5) | `pending` |
| A9 | Instances healthy; the startup script reads every name from the metadata and gcsfuse mounts the nested folder `wp-content/uploads` | R17, R23 | `pending` |
| A10 | WordPress over HTTPS with its styles, and `/wp-admin` without a redirect loop | T30 | `pending` |
| A11 | An image uploaded from WordPress is stored as `wp-content/uploads/...` in the uploads bucket and served by the backend bucket | R23, R24 | `pending` |
| A12 | The uploads bucket stays private: public access prevention enforced, and the object URL on `storage.googleapis.com` is denied | R24 | `pending` |
| A13 | Cloud CDN hits on uploads and on theme assets; none on HTML or the admin area | R25 | `pending` |
| A14 | `xmlrpc.php` answers 403; more than 5 login POSTs per minute answer 429; over 50 in 10 minutes, the IP is banned (and whether throttled requests count toward the ban) | R26 | `pending` |
| A15 | WAF matches in preview appear in the load balancer logs (`jsonPayload.previewSecurityPolicy`) | R26 | `pending` |
| A16 | The database password is in neither the state nor the saved plan, and the secret and the SQL user hold the same value | T10 | `pending` |
| A17 | A plan after the first apply passes with `terraform-plan-sa` (ephemeral read of the password and refresh of the bucket objects) | R15 | `pending` |
| A18 | No logging permission denial on a fresh instance | T01 (A16) | `pending` |
| A19 | `configs/delete-default-network.sh` removes the default network and its firewall rules | R14 | `pending` |

## Phase B — Changes through the pipeline

| # | Check | Tasks | Result |
|---|---|---|---|
| B1 | Image build from the trigger: the build VM runs in the build subnet, without an external IP or a service account, reached through IAP | R12, R13 | `pending` |
| B2 | The build VM cannot reach Cloud SQL's private range | R13 | `pending` |
| B3 | A new image rolls out to the MIG without `_ALLOW_DESTRUCTIVE` | — | `pending` |
| B4 | A rollout that replaces the function source zip passes without `_ALLOW_DESTRUCTIVE` | T06 | `pending` |
| B5 | A plan with a destroy lists it as destructive; the apply rejects it without the flag | T01 (A10, B6), R18 | `pending` |
| B6 | An instance whose startup script fails is reported unhealthy and replaced | T04 | `pending` |
| B7 | The admin panel cannot install or edit plugins and themes (`DISALLOW_FILE_MODS`) | T05 | `pending` |
| B8 | The export job runs and its file is in `<project_id>-db-backups/exports/` | — | `pending` |
| B9 | The plan and image build triggers on `main` start on their own, each with its own service account | R10, R15 | `pending` |

## Phase C — Teardown

| # | Check | Tasks | Result |
|---|---|---|---|
| C1 | `configs/destroy.sh empty-buckets` empties the backup and uploads buckets | R16, T07 | `pending` |
| C2 | `terraform destroy` finishes | T07 | `pending` |
| C3 | The reserved IP is released | T07 | `pending` |

## Errors found

### E1 — The first image build cannot read its source

Step 6, `gcloud builds submit` of `cloudbuild/packer.yaml` with `packer-build-sa`:

```text
Uploading tarball of [.] to [gs://gcp-wordpress-test-deploy_cloudbuild/source/1793024714.141722-028c1d88a5704e91b598ca88478a68db.tgz]
ERROR: (gcloud.builds.submit) INVALID_ARGUMENT: could not resolve source: googleapi: Error 403: packer-build-sa@gcp-wordpress-test-deploy.iam.gserviceaccount.com does not have storage.objects.get access to the Google Cloud Storage object. Permission 'storage.objects.get' denied on resource '//storage.googleapis.com/projects/_/buckets/gcp-wordpress-test-deploy_cloudbuild/objects/source/1793024714.141722-028c1d88a5704e91b598ca88478a68db.tgz' (or it may not exist)., forbidden
```

**Cause.** `gcloud builds submit` uploads the local directory to `gs://<project_id>_cloudbuild`, and the build reads it with the service account it runs as. Before the refactor every build ran as `terraform-cloud-build`, which had `roles/storage.admin` on the project. `packer-build-sa` only has Compute, IAP and Logging roles, and `terraform-plan-sa` has `roles/viewer`, which does not read objects. Triggers are not affected: they fetch the source from GitHub.

**Fix.** `configs/setup.sh` creates `gs://<project_id>_cloudbuild` if it does not exist and grants `roles/storage.objectViewer` on it to `terraform-plan-sa` and `packer-build-sa`; `terraform-apply-sa` already reads it with `roles/storage.admin`. The README explains the bucket in Step 5. In this project, where `setup.sh` had already run, the two bindings were added by hand.

### E2 — The plan rejects the CDN policy of the backend service

Step 7, the first plan:

```text
Error: Missing required argument

  with module.global_external_lb.google_compute_backend_service.mig,
  on modules/global_external_lb/main.tf line 191, in resource "google_compute_backend_service" "mig":
 191:   cdn_policy {

"cdn_policy.0.signed_url_cache_max_age_sec": one of
`cdn_policy.0.cache_key_policy,cdn_policy.0.signed_url_cache_max_age_sec`
must be specified
```

The same error is reported for `cdn_policy.0.cache_key_policy`.

**Cause.** For a backend service, the provider requires `cdn_policy` to set `cache_key_policy` or `signed_url_cache_max_age_sec`. The backend bucket has no such requirement. `terraform validate` passes: the check only runs at plan time.

**Fix.** An explicit `cache_key_policy` with Cloud CDN's default key: protocol, host and query string. The query string matters because WordPress versions theme and plugin assets with `?ver=`, so a new version gets a new cache entry.

The plan also shows warnings for the deprecated `enable_logging` attribute. They come from inside the official network module (`module.vpc.module.firewall_rules`), not from this code, and change nothing.
