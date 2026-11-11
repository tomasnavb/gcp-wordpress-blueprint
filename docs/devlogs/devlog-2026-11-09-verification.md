# Verification — 2026-11-09

Checklist of the deploy from scratch that verifies the refactor (task R22 in [../to-do.md](../to-do.md)) and the block that followed the installer takeover (R28 to R32, T20, T32, the maintenance window of T36, the monitoring of T18; see [devlog-2026-10-30.md](devlog-2026-10-30.md)). It replaces the checks of [devlog-2026-10-26-verification.md](devlog-2026-10-26-verification.md), which were left `pending` when that deploy was destroyed after E4. The deploy runs from the branch `refactor/naming-and-network` with `gcloud builds submit`, in a new project, before anything is merged to `main`.

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
| B1 | Smoke tests before the installation (`tests/smoke/edge-security.sh`, without upload path): all pass, with `/` and `admin-ajax.php` answering 302 to the installer | R28, R30 | `skipped` (run after the installation, not before) |
| B2 | Manual check 1: the installer only through IAP; an account outside `iap_members` is refused | R30 | `skipped` (no second account in the organization. An account outside it is refused by design: the Google-managed OAuth client of IAP only admits accounts of the organization) |
| B3 | Manual check 2: installation by the operator through IAP, in English | R30 | `done` |
| B4 | Manual checks 3 to 8: site language list, no application passwords, no file changes from the admin panel, links with the site's domain, public site without sign-in, sign-out | R29, R31, T05 | `pending` (checks 3 to 7 passed: ten languages listed, no application passwords, no "Add New" in Plugins, every link on the home page with `https://<domain>`, public site with its styles and no sign-in; check 8 left) |
| B5 | An image uploaded from WordPress is stored as `wp-content/uploads/...` in the uploads bucket and served by the backend bucket | R23, R24 | `done` (`200` with `server: UploadServer`: served by Cloud Storage through the backend bucket; object at `wp-content/uploads/2026/11/`) |
| B6 | Smoke tests after the installation, with the upload path: all pass, `admin-ajax.php` answering 400 with body `0` | R28, R30 | `done` (all edge checks passed after E7, the upload included) |
| B7 | The uploads bucket stays private: public access prevention enforced, and the object URL on `storage.googleapis.com` is denied | R24 | `done` (`403` on the object URL at `storage.googleapis.com`) |
| B8 | Cloud CDN hits on uploads and on theme assets; none on HTML or the admin area | R25 | `done` (upload and theme `style.min.css`: `age` set, `max-age=3600`; home page: no `age`, not cached. The admin area is behind IAP and was not measured: HTML, same rule as the home page) |
| B9 | More than 5 `POST /wp-login.php` per minute from one IP answer 429; over 50 in 10 minutes, the IP is banned. Note whether throttled requests count toward the ban | R26 | `done` (`429` from priority 200 once past 5 POSTs in a minute, before IAP. The ban, over 50 in 10 minutes, `skipped`: it would block the operator IP for 30 minutes) |
| B10 | The load balancer logs show the Cloud Armor rule of each denial (rules 50, 100, 150) and the WAF matches in preview (`jsonPayload.previewSecurityPolicy`) | R26 | `pending` (priority 200 and 50 seen; 50 also blocked real scanners requesting `/.env`, `/.env.bak` and wallet paths with the load balancer IP as host; 100 and 150 left) |

## Phase C — Database

| # | Check | Tasks | Result |
|---|---|---|---|
| C1 | The database password is in neither the state nor the saved plan, and the secret and the SQL user hold the same value | T10 | `pending` |
| C2 | Backup configuration of the instance: binary logs on, 8 retained backups, 7 days of logs, window at 02:00 UTC | T32 | `pending` |
| C3 | Maintenance window of the instance: Sunday, 04:00 UTC, `stable` (`gcloud sql instances describe ... --format="yaml(settings.maintenanceWindow)"`) | T36 | `pending` |
| C4 | The export job runs and its file is in `<project_id>-db-backups/exports/` | — | `pending` |
| C5 | Failover (`tests/resilience/sql-failover.sh`): operation `DONE`, primary in the former standby zone, same private IP, site answering again. Record the downtime and the operation's `startTime` and `endTime` | — | `pending` |

## Phase D — Monitoring

| # | Check | Tasks | Result |
|---|---|---|---|
| D1 | The image build log shows the Ops Agent 2.73.0 installed and the status page check passing | T18 | `pending` |
| D2 | On an instance: `google-cloud-ops-agent` running, no permission errors in its logs (`sudo journalctl -u google-cloud-ops-agent*`), and `curl -s localhost/server-status?auto` answering | T18 | `pending` |
| D3 | Metrics Explorer shows `workload.googleapis.com/apache.requests` and `agent.googleapis.com/memory/percent_used` for both instances | T18 | `pending` |
| D4 | Only the Apache error log in Cloud Logging (`log_id("apache_error")`), no `apache_access` | T18 | `pending` |
| D5 | Before the installation the uptime check fails (content match), and passes from every region after it. The content match `wp-content/themes` was experimental: with the site up, `curl -s https://<domain>/` showed the REST API link `https://api.w.org` on the home page, which WordPress prints whatever the theme; it replaced the first string in `monitoring.tf` | T18 | `pending` (string replaced; the uptime check passing from every region with it is left) |
| D6 | The uptime alert email reaches `IAP_USER_EMAIL` while the site is not installed (D5). Email channels need no verification | T18 | `pending` |
| D7 | The uptime alert fires during the failover (C5) if the downtime passes two minutes, or with the instances stopped, and closes when the site is back | T18 | `pending` |
| D8 | The export alert targets the right entries: in Logs Explorer, its filter without the severity and status conditions matches the scheduler job and function request entries of the export run of C4. A real failure is not forced: it would need breaking the function | T18, T37 | `pending` |
| D9 | The dashboard `wp-blueprint-dashboard-prod` shows data in every chart | T18 | `pending` |
| D10 | A second plan after the apply shows no change to the dashboard | T18 | `pending` |

## Phase E — Changes through the pipeline

| # | Check | Tasks | Result |
|---|---|---|---|
| E1 | A plan after the first apply passes with `terraform-plan-sa` (ephemeral read of the password and refresh of the bucket objects) | R15 | `pending` |
| E2 | Image build from the trigger: the build VM runs in the build subnet, without an external IP or a service account, reached through IAP | R12, R13 | `pending` |
| E3 | The build VM cannot reach Cloud SQL's private range | R13 | `pending` |
| E4 | A new image rolls out to the MIG without `_ALLOW_DESTRUCTIVE` | — | `pending` |
| E5 | A rollout that replaces the function source zip passes without `_ALLOW_DESTRUCTIVE` | T06 | `pending` |
| E6 | A plan with a destroy lists it as destructive; the apply rejects it without the flag | T01, R18 | `pending` |
| E7 | An instance whose startup script fails is reported unhealthy and replaced | T04 | `pending` |
| E8 | The plan and image build triggers on `main` start on their own, each with its own service account | R10, R15 | `pending` |
| E9 | `configs/delete-default-network.sh` removes the default network and its firewall rules | R14 | `pending` |

## Phase F — Teardown

| # | Check | Tasks | Result |
|---|---|---|---|
| F1 | `configs/destroy.sh empty-buckets` empties the backup and uploads buckets | R16, T07 | `pending` |
| F2 | `terraform destroy` finishes | T07 | `pending` |
| F3 | The reserved IP is released | T07 | `pending` |

## Errors found

### E1 — The image build cannot unzip Packer: python3 not found

Step 6, `gcloud builds submit` of `cloudbuild/packer.yaml` (check A5):

```text
Step #0 - "install-packer": Status: Downloaded newer image for gcr.io/google.com/cloudsdktool/cloud-sdk:slim
Step #0 - "install-packer": gcr.io/google.com/cloudsdktool/cloud-sdk:slim
Step #0 - "install-packer": /tmp/packer.zip: OK
Step #0 - "install-packer": sh: 5: python3: not found
Finished Step #0 - "install-packer"
ERROR
ERROR: build step 0 "gcr.io/google.com/cloudsdktool/cloud-sdk:slim" failed: step exited with non-zero status: 127
```

**Cause.** The step ran in `cloud-sdk:slim`, a floating tag that always points to the latest gcloud CLI. On this day it resolved to `592.0.0-slim` (`sha256:08c9cb2c…`, published 2026-11-03), which no longer includes `python3`, and the step unzipped Packer with `python3 -m zipfile`. The Packer download and its checksum were fine (`/tmp/packer.zip: OK`). Nothing was created in the project: the build stopped at step 0. No release note of the gcloud CLI announcing the change was found.

**Fix.**

- The step downloads, verifies and unzips Packer in Alpine, whose busybox has `wget`, `sha256sum` and `unzip`. Packer still runs in the gcloud image, which it needs for the IAP tunnel.
- Every step image of the three pipelines is pinned to an exact tag and its digest, checked against each registry: `cloud-sdk:592.0.0-slim`, `alpine:3.24.3`, `python:3.12.15-alpine3.24`, `hashicorp/terraform:1.15.7`. Before, `cloud-sdk:slim` and `alpine` floated, and `python:3.12-alpine` fixed only the minor version, against the rule that nothing used to build or deploy is unpinned. An image upgrade is now a change of tag and digest in a pull request.

### E2 — Four language packs no longer match their checksums

Step 6, second image build, after E1 was fixed. The Ops Agent block passed (`mod_status` loaded, `/server-status` answering); the build stopped at the checksum check of the WordPress downloads:

```text
==> wp-blueprint-web.googlecompute.wordpress: + cd /tmp/downloads
==> wp-blueprint-web.googlecompute.wordpress: + sha256sum --strict -c /tmp/checksums.sha256
...
Build 'wp-blueprint-web.googlecompute.wordpress' errored after 3 minutes 31 seconds: Script exited with non-zero exit status: 1. Allowed exit codes are: [0]
```

**Cause.** WordPress.org rebuilt four core language packs of 7.1.3 after their checksums were committed (`0dd8a7c`, 2026-10-28 13:57 UTC), without a new version. The `updated` field of the translations API (`https://api.wordpress.org/translations/core/1.0/?version=7.1.3`):

| File | Rebuilt (UTC) |
|---|---|
| `wordpress-7.1.3-de_DE.zip` | 2026-10-28 15:30 |
| `wordpress-7.1.3-nl_NL.zip` | 2026-10-28 15:27 |
| `wordpress-7.1.3-pl_PL.zip` | 2026-10-28 15:10 |
| `wordpress-7.1.3-ru_RU.zip` | 2026-10-28 17:45 |

The other 16 files, WordPress 7.1.3 included, still match. The new packs hold the expected file types (`.po`, `.mo`, `.json`, `.l10n.php`). The check did its job: the build stopped on files that differ from the ones reviewed. The README describes this case in *Update the WordPress image*.

**Fix.** `bash packer/scripts/update-checksums.sh`, which checks WordPress against its official SHA1 and rewrites `checksums.sha256`. The diff changes only those four lines, and the new values match an independent download of each file.

### E3 — The apply cannot create the log-based alert

Step 8, the first apply:

```text
Error: Error creating AlertPolicy: googleapi: Error 403: projects/gcp-wordpress-test-v2 -> Permission 'logging.notificationRules.create' denied on resource '//logging.googleapis.com/projects/gcp-wordpress-test-v2/locations/global' (or it may not exist).

  with google_monitoring_alert_policy.export_failure,
  on monitoring.tf line 134, in resource "google_monitoring_alert_policy" "export_failure":
```

**Cause.** An alert policy with `condition_matched_log` is not only a Monitoring resource: Cloud Logging creates a notification rule for it, which needs `logging.notificationRules.create` ([Configure log-based alerting policies](https://docs.cloud.google.com/logging/docs/alerting/log-based-alerts)). `roles/monitoring.editor`, granted to `terraform-apply-sa` for T18, does not include it; `roles/logging.admin` and `roles/logging.configWriter` do ([Cloud Logging roles](https://docs.cloud.google.com/iam/docs/roles-permissions/logging)). The other alert policies, based on metrics, do not need it.

**Fix.** `configs/setup.sh` grants `roles/logging.configWriter` to `terraform-apply-sa`, the smaller of the two. In this project, where `setup.sh` had already run, the binding is added by hand:

```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:terraform-apply-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/logging.configWriter"
```

### E4 — Cloud Armor rejects capture groups in the rule expressions

Step 8, the same apply, for both security policies (the domain is replaced by `<domain>`):

```text
Error: Error creating SecurityPolicy: googleapi: Error 400: Invalid value for field 'resource.rules[1].match.expr': 'request.path.urlDecodeUni().lower().matches('/wp-admin|/wp-admin(/|$)|/wp-login[.]php') && !request.path.urlDecodeUni().lower().matches('^/+wp-admin/+admin-ajax[.]php$')'. Failed with error: generic::invalid_argument: invalid regular expression: /wp-admin|/wp-admin(/|$)|/wp-login[.]php, generic::invalid_argument: capture groups are not allowed while parsing Cloud Armor rule matcher expression: ...

  with module.global_external_lb.google_compute_security_policy.wordpress,
  on modules/global_external_lb/main.tf line 454, in resource "google_compute_security_policy" "wordpress":

Error: Error creating SecurityPolicy: googleapi: Error 400: Invalid value for field 'resource.rules[13].match.expr': '!has(request.headers['host']) || !request.headers['host'].lower().matches('^(<domain>)(:[0-9]+)?$')'. Failed with error: generic::invalid_argument: invalid regular expression: ^(<domain>)(:[0-9]+)?$, generic::invalid_argument: capture groups are not allowed while parsing Cloud Armor rule matcher expression: ...

  with module.global_external_lb.google_compute_security_policy.iap[0],
  on modules/global_external_lb/main.tf line 519, in resource "google_compute_security_policy" "iap":
```

**Cause.** The module built two regular expressions with groups: the allowed hosts of rule 50 (`^(a|b)(:[0-9]+)?$`) and the protected paths of rule 150 (`/wp-admin(/|$)`). RE2 accepts them, but Cloud Armor's rule parser rejects capture groups. The [rules language reference](https://docs.cloud.google.com/armor/docs/rules-language-reference) does not say so; only the API does, so `terraform validate` and the plan passed. The 15 path variants of R30 had been checked against the expression with a regular expression engine, not against Cloud Armor.

**Fix.** Both expressions are generated without groups, by expanding the alternatives:

| Rule | Before | After |
|---|---|---|
| 50, hosts | `^(a[.]com\|b[.]com)(:[0-9]+)?$` | `^a[.]com$\|^a[.]com:[0-9]+$\|^b[.]com$\|^b[.]com:[0-9]+$` |
| 150, paths | `/wp-admin\|/wp-admin(/\|$)\|/wp-login[.]php` | `/wp-admin\|/wp-admin/\|/wp-admin$\|/wp-login[.]php` |

The new expressions were generated with the module's own Terraform code and compared with the old ones on 27 cases (valid and invalid hosts, with and without a port; the path variants of the smoke tests and public paths): no difference. The apply that confirms Cloud Armor accepts them is the next one.

### E5 — Cloud Armor quota of rules with an expression

Step 8, the apply after E3 and E4. The public security policy was created, so Cloud Armor accepts the expressions without groups (E4); the policy behind IAP failed:

```text
Error: Error waiting for Creating SecurityPolicy "wp-blueprint-lb-armor-iap-prod": Quota 'SECURITY_POLICY_CEVAL_RULES' exceeded.  Limit: 20.0 globally.
	metric name = compute.googleapis.com/security_policy_ceval_rules
	limit name = SECURITY-POLICY-CEVAL-RULES-per-project
	limit = 20

  with module.global_external_lb.google_compute_security_policy.iap[0],
  on modules/global_external_lb/main.tf line 529, in resource "google_compute_security_policy" "iap":
```

**Cause.** The quota counts every rule with an expression across all the global security policies of the project, preconfigured WAF rules included ([Cloud Armor quotas and limits](https://docs.cloud.google.com/armor/quotas)); the default rule (`*`) does not count. When R30 split the policy in two, the eleven WAF rules went into both:

| Policy | Rules with an expression | Total |
|---|---|---|
| Public | 50 hosts, 100 xmlrpc, 150 protected paths, 11 WAF | 14 |
| Behind IAP | 50 hosts, 200 login rate limit, 11 WAF | 13 |
| Project | | 27 > 20 |

**Options considered.**

| Option | Rules | Outcome |
|---|---|---|
| No WAF in the policy behind IAP | 16 | **Chosen.** Behind IAP only the operator, already signed in with Google, reaches WordPress; there the WAF would mostly flag the post editor. Gives up WAF filtering of a stolen operator session |
| Group the rule sets, up to five `evaluatePreconfiguredWaf()` per rule | 11 | Kept as the next step if more rules are needed. One priority for five rule sets makes removing a noisy one a change to a shared rule |
| Ask for a quota increase | 27 | **Dropped.** Not reproducible: every other project deploying the repository hits the same limit |

**Fix.** `iap_deny_rules` holds only the host rule; the login rate limit stays. The README and the rule table of devlog-2026-10-30 say the WAF is on the public backend only, and why. The policy behind IAP was never created, so nothing had to be removed.

### E6 — The apply cannot grant access to the admin area

Step 8, the apply of a plan generated after E5 (the operator email is replaced by `<operator-email>`):

```text
Error: Error retrieving IAM policy for iap webbackendservice "projects/gcp-wordpress-test-v2/iap_web/compute/services/wp-blueprint-lb-backend-iap-prod": googleapi: Error 403: Permission 'iap.webServices.getIamPolicy' denied on resource '//iap.googleapis.com/projects/gcp-wordpress-test-v2/iap_web/compute/services/wp-blueprint-lb-backend-iap-prod' (or it may not exist).

  with module.global_external_lb.google_iap_web_backend_service_iam_member.accessors["user:<operator-email>"],
  on modules/global_external_lb/main.tf line 306, in resource "google_iap_web_backend_service_iam_member" "accessors":
```

An earlier apply of this session used a plan generated before the fix of E5 and hit the same quota error again; it is not a separate issue.

**Cause.** The member binding of R30 reads the IAM policy of the backend service behind IAP and writes it back. None of the roles of `terraform-apply-sa` holds `iap.webServices.*` permissions. From [IAP roles and permissions](https://docs.cloud.google.com/iam/docs/roles-permissions/iap): `getIamPolicy` is in `iap.admin`, `iam.securityAdmin` and `iam.securityReviewer`; `setIamPolicy` only in `iap.admin` and `iam.securityAdmin`. `terraform-plan-sa` already reads it through `iam.securityReviewer`; the plan did not fail only because the backend service did not exist yet. Same class of error as E3: the pipeline roles were not reviewed when the resource was added.

**Fix.** `configs/setup.sh` grants `roles/iap.admin` to `terraform-apply-sa`: the narrowest role that writes the policy, where `iam.securityAdmin` would cover the IAM of the whole project. In this project the binding is added by hand:

```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:terraform-apply-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/iap.admin"
```

### E7 — Three smoke test failures that are expectations of the test, not gaps

Smoke tests after the installation (check B6). Every edge check passed except three (the domain is replaced by `<domain>`):

```text
FAIL  /./wp-admin/ (expected 403, 401 or the IAP sign-in)         302 https://<domain>/wp-admin/
FAIL  /wp-admin/admin-ajax.php/../install.php (expected 403, 401 or the IAP sign-in)  302 https://<domain>/wp-admin/install.php
FAIL  HTTP redirects to HTTPS (expected 301 to https://<domain>/)  301 https://<domain>:443/
```

**Cause.** Google's front end normalizes paths with dot segments (`/./`, `/../`) and answers them itself, with a redirect to the same URL with the path normalized, before any backend. Two independent checks confirm the requests never reached WordPress:

| Check | `/./wp-admin/` | `/health.php` (answered by Apache) |
|---|---|---|
| `server` header | absent | `Apache/2.4.68 (Debian)` |
| `via: 1.1 google` header | absent: no backend involved | present |
| Apache access log on both instances | not found | — |

The load balancer request logs had no entry for them either. A browser that follows the redirect lands on `/wp-admin/` or `/wp-admin/install.php`, which go through IAP. The third failure is the HTTP redirect writing the default port, `https://<domain>:443/`: the same URL.

**Fix.** The smoke test accepts, for the two paths with dot segments, a redirect to the normalized path, and then requests that path and requires the IAP sign-in: accepting the redirect alone would not prove the target is protected. The HTTP check accepts `https://<domain>/` and `https://<domain>:443/`. `docs/test-procedure.md` lists who answers each case. The new function was checked offline with stubbed responses: it passes when the target is behind IAP and fails when it is not, or when the redirect goes elsewhere.
