# Verification — 2026-11-11

Checklist of the second deploy from scratch of the branch `refactor/naming-and-network`, in a new project, after the fixes of the 2026-11-09 verification (E1 to E7 in [devlog-2026-11-09-verification.md](devlog-2026-11-09-verification.md)). A clean bootstrap confirms those fixes, which on 2026-11-09 were applied to a project already bootstrapped. How each test is run is in [../test-procedure.md](../test-procedure.md).

The site's domain is written `<domain>`.

Result values: `pending`, `done`, `failed`, `skipped`. When a check passes, the matching task in the to-do is set to `done`.

## 1. Bootstrap and clean deploy

| # | Check | Result |
|---|---|---|
| 1.1 | `setup.sh` grants `terraform-apply-sa` the roles added on 2026-11-09 (`monitoring.editor`, `logging.configWriter`, `iap.admin`); nothing granted by hand | `done` |
| 1.2 | Image build, plan and apply pass at the first attempt (E1 to E6 of 2026-11-09) | `done` (the image build took 8 min 18 s; the README says about 5 minutes, T08) |
| 1.3 | The apply prints `load_balancer_ip`, `site_urls` and `ssl_certificate_name` | `done` |
| 1.4 | Two instances, in two zones | `done` |

## 2. Before the WordPress installation

| # | Check | Result |
|---|---|---|
| 2.1 | Smoke tests: `/` and `admin-ajax.php` answer 302 to the installer, the installer only through IAP | `done` (18 passed, after E1) |
| 2.2 | The uptime check fails and the uptime alert opens an incident (D5, D6 of 2026-11-09) | `done` (seen in Monitoring, Incidents. The email is not checked: the operator identity has no mailbox) |

## 3. After the installation

| # | Check | Result |
|---|---|---|
| 3.1 | Smoke tests with an upload: all pass | `done` |
| 3.2 | The uptime check passes from the three regions with the content match `https://api.w.org/`, and the incident closes by itself | `done` |
| 3.3 | Without an IAP session, `/wp-admin/` asks for the Google sign-in (B4, check 8) | `done` (a new incognito window led to IAP. `?gcp-iap-mode=CLEAR_LOGIN_COOKIE` only works on a path behind IAP: on `/` it reaches the public backend) |
| 3.4 | Cloud Armor decisions in the load balancer logs, priorities 100 and 150 (B10) | `done` (`/xmlrpc.php` with 100; `/WP-LOGIN.PHP` and `/wp-login.php/x` with 150) |
| 3.5 | TLS 1.1 rejected: `curl --tlsv1.1 --tls-max 1.1 https://<domain>` | `done` (`* TLSv1.1 (IN), TLS alert, protocol version (582)`: the alert comes from the load balancer. The first try, without `--ciphers 'DEFAULT@SECLEVEL=0'`, failed on the client with `no protocols available`, before any connection, and proved nothing) |

## 4. Database

| # | Check | Result |
|---|---|---|
| 4.1 | The database password is not in the Terraform state (T10) | `done` (`grep -cF` of the secret value in the state: 0. The saved plan was not checked) |
| 4.2 | Backups: binary logs, 8 retained backups, 7 days of logs, window at 02:00 UTC (T32) | `done` (also `transactionalLogStorageState: CLOUD_STORAGE`) |
| 4.3 | Maintenance window: Sunday, 04:00 UTC, `stable` (T36) | `done` |
| 4.4 | The export job runs and its file is in the backup bucket | `done` |
| 4.5 | Failover with `tests/resilience/sql-failover.sh` | `done` (see below) |
| 4.6 | The failover does not open an uptime incident (D7) | `done` (none opened: the downtime was far under the two minutes of the alert) |
| 4.7 | Point-in-time restore to a new instance (T33): `gcloud sql instances clone wp-blueprint-db-prod wp-blueprint-db-restore-test --point-in-time=<a minute before>` | `done` (the clone is `RUNNABLE` and holds the `wordpress` database, `utf8mb4` / `utf8mb4_unicode_ci` as set by Terraform; deleted afterwards. WordPress reading the restored data is not checked: there is no admin path to the database, T45) |

Failover, 2026-11-11:

| Measure | Value |
|---|---|
| Operation | `FAILOVER`, `DONE`, 15:02:39 to 15:03:12 UTC (33 s) |
| Site downtime | 10.6 s, from +15.5 s to +26.1 s after the request; 8 requests answered 500, 16 answered 200 |
| Primary zone | `europe-west1-c` to `europe-west1-b` |
| Private IP | Unchanged, the instances reconnected by themselves |

Second run, the same day, back to the first zone:

| Measure | Value |
|---|---|
| Operation | `FAILOVER`, `DONE`, 16:48:05 to 16:48:39 UTC (34 s) |
| Site downtime | 20.9 s, from +4.6 s to +25.5 s; 2 requests with no answer within the 3 s timeout (`000`), then 9 answered 500 |
| Primary zone | `europe-west1-b` to `europe-west1-c` |
| Private IP | Unchanged |

Across both runs, the downtime was 10 to 21 s. The `000` of the second run are requests that hung: WordPress was connecting to the old primary, which had stopped answering without closing the connection, and PHP waited instead of failing at once. A shorter connection timeout in PHP (`mysqli.connect_timeout`) would turn that wait into a fast error; left as an improvement.

Point-in-time restore, 2026-11-11: the first `clone` call returned `is taking longer than expected` after about 10 minutes, with the instance in `PENDING_CREATE`; `gcloud` stops waiting, the operation goes on. A `delete` run right after it, then interrupted with Ctrl-C, had already reached the API and cancelled the clone (`gcloud sql operations wait` answered `[CANCELLED]`). The second `clone`, run with `--async` and followed with `gcloud sql operations wait --timeout=unlimited`, finished. A restore to a regional instance takes over 10 minutes: wait for the operation before anything else.

The instances stayed healthy during the failover: `/health.php` does not use the database, on purpose. The site was down only for the part of the operation when the primary switched.

## 5. Monitoring

| # | Check | Result |
|---|---|---|
| 5.1 | Ops Agent active on both instances, reading `/server-status?auto` (D2) | `done` |
| 5.2 | No Apache access log in Cloud Logging, the error log present (D4) | `done` (the error entries are the smoke test's `/server-status` requests, `AH01630: client denied by server configuration`, and the rolling update of the domain fix) |
| 5.3 | Every chart of the dashboard has data (D3, D9) | `done` (after E2: the scoreboard replaced "Apache current connections", which had no data) |
| 5.4 | The filter of the export alert matches the scheduler and function entries of 4.4 (D8) | `done` (in the last day: the scheduler entries with `job_id` `wp-blueprint-db-export-job-prod`, `INFO`, and the function request with `service_name` `wp-blueprint-db-backup-fn-prod`, status 200. Logs Explorer showed nothing at first only because its default range is the last hour) |
| 5.5 | A plan after the apply shows no change to the dashboard (D10) | `done` (after E3: the plan with the fix updated the dashboard once, and the plan after its apply showed `No changes`) |

## 6. Pipeline

| # | Check | Result |
|---|---|---|
| 6.1 | The `_DOMAIN_NAMES` substitution of the two plan triggers holds the right domain (E1) | `done` (it holds the `.dev` domain after a correction by hand in the console: `setup.sh` stores the exported value in the triggers, so a mistyped `DOMAIN_NAMES` has to be corrected in the plan command and in both triggers) |
| 6.2 | Image build from the trigger: build subnet, no external IP or service account, through IAP; the build VM cannot reach Cloud SQL (E2, E3 of 2026-11-09) | `done` (screenshot of the build VM in `build-subnet-prod-europe-west1`; no external IP or service account by the Packer template, and the build could only reach it through IAP) |
| 6.3 | The new image rolls out to the MIG without `_ALLOW_DESTRUCTIVE` (E4 of 2026-11-09) | `done` (the plan replaced the instance template, the apply passed without `_ALLOW_DESTRUCTIVE`, and the MIG replaced both instances one at a time) |
| 6.4 | `configs/delete-default-network.sh` removes the default network (E9 of 2026-11-09) | `done` |

Skipped, with their reason: B2 (no second account in the organization), the login ban (it would block the operator IP for 30 minutes), E5 and E7 (they need forced code changes), E6 (`check_destructive.py` unchanged since D03) and E8 (after the merge to `main`).

## 7. Screenshots

| # | Check | Result |
|---|---|---|
| 7.1 | The twelve screenshots of the README, retaken (T09) | `done` (retaken: triggers, builds, VM instances, healthy backend, Cloud SQL, secrets, scheduler, uploads bucket. The two WordPress screenshots of 2026-10-11 are kept. The HTTP redirect is in the smoke test screenshot; the TLS one was retaken with 3.5) |
| 7.2 | New: smoke tests, Cloud Armor policy, scanner denials in the logs, dashboard, uptime check, failover | `done` (smoke tests, Cloud Armor policies, dashboard, uptime checks, uptime alert, failover, export job, MIG rolling update, Packer VM subnet, default network removal) |

## 8. Teardown

| # | Check | Result |
|---|---|---|
| 8.1 | `configs/destroy.sh empty-buckets`, `terraform destroy`, reserved IP released | `pending` |

## Errors found

### E1 — The certificate is requested for a mistyped domain

Section 2, smoke tests before the installation. Every HTTPS check failed without an HTTP response; only the HTTP redirect passed:

```text
FAIL  Host: the load balancer IP (expected 403)                   000
FAIL  Host: the site's domain (expected 200, or 302 to the installer)  000
...
PASS  HTTP redirects to HTTPS                                     301 https://<domain>:443/
1 passed, 17 failed, 1 skipped
```

The certificate:

```text
NAME: wp-blueprint-lb-cert-prod-32f52288
MANAGED_STATUS: PROVISIONING
<domain with .com>: FAILED_NOT_VISIBLE
```

**Cause.** `DOMAIN_NAMES` was exported with `.com` instead of the site's `.dev` before `configs/setup.sh` and the plan. The DNS record of the real domain pointed to the new IP, but the certificate, the host rule of Cloud Armor (rule 50) and the uptime check were all for the `.com` name, which does not point to the load balancer: the certificate never left `PROVISIONING`, and the load balancer could not complete a TLS handshake for the real domain (`000`). The HTTP redirect passed because it does not check the host. The uptime alert opened because the `.com` name does not resolve, not because of the content match. The validation of `domain_names` checks the format, not that the domain is the operator's or points to the load balancer.

**Fix.** A new plan and apply with the right domain: a new certificate (its name carries a hash of the domains, and `create_before_destroy` creates it first), rule 50 of both policies, the uptime check, and the `site-url` metadata, which replaced the instance template. The two plan triggers keep the substitution stored by `setup.sh` and are checked in 6.1. A possible improvement, not done: a check in `setup.sh` that the domains resolve to the reserved IP before creating the triggers.

### E2 — The Apache connections chart has no data

Section 5, the dashboard. Every chart but one had data:

```text
Query A: Cannot find metric(s) that match type = "workload.googleapis.com/apache.current_connections". If a metric was created recently, it could take up to 10 minutes to become available. Please try again soon.
```

**Cause.** The Apache receiver of the Ops Agent takes `apache.current_connections` from the `ConnsTotal` field of `/server-status?auto`, which only the `event` and `worker` MPMs report. The image installs `libapache2-mod-php`, which runs Apache with the `prefork` MPM. On an instance, `/server-status?auto` reports `BusyWorkers` and `IdleWorkers` and no `Conns*` line, so the metric is never created.

**Fix.** The chart is replaced by "Apache scoreboard by state" (`apache.scoreboard`, grouped by state), which `prefork` reports: what each slot is doing (waiting, reading, writing, keepalive). A comment in `monitoring.tf` and the README say why there is no connections chart. Moving to the `event` MPM with PHP-FPM would bring the metric back, and is a larger change to the image.

### E3 — Every plan updates the dashboard in place

Section 5, the plan after the apply of E2 (check D10). With nothing changed, the plan updated `google_monitoring_dashboard.main` again (the project number is replaced by `<project-number>`):

```text
# google_monitoring_dashboard.main will be updated in-place
  ~ dashboard_json = jsonencode(
      ~ {
          - etag         = "7083a5898ee9786fcd642a71b43eaba6"
          ~ mosaicLayout = {
              ~ tiles   = [
                  ~ {
                      ~ widget = { ~ xyChart = { ~ dataSets = [ ~ { - targetAxis = "Y1" ... } ] } }
                      + xPos   = 0
                      + yPos   = 0
                    },
                  ...
                  ~ { ... ~ aggregation = { + groupByFields = [] ... } ... },
          - name         = "projects/<project-number>/dashboards/<dashboard-id>"
```

**Cause.** The API normalizes the dashboard JSON it stores: it drops fields equal to 0 (`xPos`, `yPos`) and empty lists (`groupByFields`), and adds the default axis of each series (`targetAxis = "Y1"`). Terraform compares the JSON of the configuration with the stored one. The provider ignores the fields the API adds at the top level (`etag`, `name`), not inside the list of tiles, so every plan showed a change.

**Fix.** The JSON is generated the way the API stores it: `xPos` and `yPos` only when not 0, `groupByFields` only when not empty, and `targetAxis = "Y1"` written in each series. The dashboard is the same. The JSON was rendered offline with the same expression to check the tiles. `lifecycle { ignore_changes = [dashboard_json] }` was ruled out: it would hide the diff and also stop real changes to the dashboard, such as the one of E2. The check passes when the plan after the apply of the fix shows `No changes`.
