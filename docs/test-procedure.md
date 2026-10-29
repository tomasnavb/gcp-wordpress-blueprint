# Test procedure

How a deploy of this project is tested, and what each test proves. The results of each run are recorded in the verification checklist of that deploy (`docs/devlogs/devlog-YYYY-MM-DD-verification.md`); this file describes how to test, not what a given run found.

The edge security tested here comes from the installer takeover of the 2026-10-26 verification deploy (E4 in [devlog-2026-10-26-verification.md](devlogs/devlog-2026-10-26-verification.md)): the site serves only its own domains, the admin area and the login are only reachable through IAP, and WordPress takes its address from configuration, never from the request.

## Levels

| Level | What it proves | When | How |
|---|---|---|---|
| 1. Static checks | The configuration is well formed | Before every commit, and in the plan pipeline on every PR | `terraform fmt -check -recursive`, `terraform validate`, `packer fmt -check`, `packer validate` |
| 2. Smoke tests | The deployed site answers as expected from outside | After every apply | [tests/smoke/edge-security.sh](../tests/smoke/edge-security.sh) |
| 3. Manual checks | What needs a browser and a person: signing in with Google, the installer, the admin panel | After a deploy from scratch, and after any change to the load balancer, Cloud Armor, IAP or `wp-config.php` | The steps in [Level 3](#level-3-manual-checks) |

Not covered yet: tests of the Terraform configuration itself (`terraform test`), which would check in CI, without deploying anything, that the modules build the expected rules and reject invalid input.

Known limit: there is no staging environment. In a real production setup, levels 2 and 3 run first on a separate deploy (`environment = "dev"`) and only then on production. Here they run on the only deploy there is.

## Level 1: static checks

From `terraform/`:

```bash
terraform fmt -check -recursive
terraform validate
```

From the repository root:

```bash
packer fmt -check packer/
packer validate -var project_id=example-project packer/
```

`terraform validate` needs `terraform init`. To run it locally without touching the state bucket, initialize without the backend: `terraform init -backend=false`.

## Level 2: smoke tests

The script only sends HTTP requests with `curl`; it changes nothing. Run it from any machine with `bash` and `curl`, Cloud Shell included:

```bash
bash tests/smoke/edge-security.sh <domain> <load-balancer-ip> [upload-path]
```

- `<domain>`: the first of `domain_names`.
- `<load-balancer-ip>`: the `load_balancer_ip` output of the apply.
- `[upload-path]`: optional, the path of a file uploaded from WordPress, to check the backend bucket. Leave it out before the first upload.

It needs the certificate to be `ACTIVE`: the requests use the site's domain as the TLS name. It does not need DNS, because it sends the requests to the given IP.

Expected results:

| Request | Expected | What answers |
|---|---|---|
| `Host:` the load balancer IP | 403 | Cloud Armor, "Block unknown hosts" |
| `Host:` another domain | 403 | Cloud Armor, "Block unknown hosts" |
| `Host:` the site's domain, `/` | 200; before the installation, 302 to `/wp-admin/install.php`, which WordPress sends for any request until it is installed | WordPress |
| `/wp-admin/`, `/wp-admin`, `/wp-admin/install.php`, `/wp-login.php` | The IAP sign-in: 302 to `accounts.google.com`, or 401 | IAP |
| `/wp-login.php/x`, `//wp-admin/install.php`, `/./wp-admin/`, `/wp-%61dmin/`, `/WP-LOGIN.PHP`, `/wp-admin/admin-ajax.php/../install.php` | 403, or the IAP sign-in | Cloud Armor, "Block protected paths outside IAP", or IAP if the load balancer normalized the path first |
| `/wp-admin/admin-ajax.php` | 400 with the body `0`, which WordPress answers when no `action` is given; before the installation, 302 to `/wp-admin/install.php` | WordPress, without IAP: neither Cloud Armor nor IAP answers like that |
| `/health.php` | 200 | WordPress |
| `/xmlrpc.php` | 403 | Cloud Armor, "Block xmlrpc.php" |
| An upload | 200 | Backend bucket |
| `http://` | 301 to `https://` | HTTP redirect URL map |

The script prints `PASS` or `FAIL` per check, with the status and the `Location` header it got, and exits with 1 if any check fails. A `FAIL` with status `200` on an admin or login path means WordPress was reached without IAP: stop and review the URL map and the Cloud Armor rules before using the site.

To see which Cloud Armor rule answered a request, read the load balancer request logs:

```bash
gcloud logging read 'resource.type="http_load_balancer" AND jsonPayload.enforcedSecurityPolicy.outcome="DENY"' \
  --project=<project_id> --freshness=1h --limit=20 \
  --format="table(timestamp, httpRequest.requestUrl, httpRequest.status, jsonPayload.enforcedSecurityPolicy.name, jsonPayload.enforcedSecurityPolicy.priority)"
```

## Level 3: manual checks

Two Google accounts of the organization are needed: one in `iap_members`, and one that is not.

1. **The installer is only reachable through IAP.** In a private browser window, open `https://<domain>/`. Before the installation it redirects to `/wp-admin/install.php`, and that goes to the Google sign-in. Sign in with the account that is **not** in `iap_members`: IAP answers that you do not have access. The installer must not appear.
2. **Installation by the operator.** In a new private window, sign in with the account in `iap_members`. The installer appears, in English: `DISALLOW_FILE_MODS` turns off its language chooser. Complete it. Use an admin username that is not `admin` and a strong password, and keep them in a password manager.
3. **Site language.** In *Settings → General → Site Language*, English (United States), which comes with WordPress, and the ten installed languages appear: Deutsch, Español, Español de Argentina, Français, Italiano, Nederlands, Polski, Português do Brasil, Русский and 日本語. Choose one and save: the admin panel changes language. The list must not offer languages to download.
4. **Application passwords are off.** In *Users → Profile*, there is no "Application Passwords" section.
5. **No file changes from the admin panel.** In *Plugins*, there is no "Add New" button, and *Appearance* has no theme or file editor (`DISALLOW_FILE_MODS`).
6. **The site address does not follow the Host header.** View the source of the home page: every link uses `https://<domain>`. Then run the smoke tests (level 2): a request with another `Host` must get a 403, never a page with links to that host.
7. **The public site works without signing in.** In a private window, without signing in, open the home page and a post: they load with their styles, and no Google sign-in appears.
8. **Sign out.** After signing out of WordPress, `https://<domain>/wp-admin/` still goes through IAP; after signing out of Google too, it asks for the Google sign-in again.

Record each check in the verification checklist of the deploy, with its result (`done`, `failed`, `skipped`) and the exact text of any error.
