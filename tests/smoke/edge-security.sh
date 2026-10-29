#!/bin/bash
set -uo pipefail

# ==============================================================
# Smoke tests of the edge security of a deployed site: what the load balancer, Cloud Armor and IAP
# answer from outside. Read-only: it only sends HTTP requests with curl and changes nothing.
#
# Usage, after an apply (see docs/test-procedure.md):
#   bash tests/smoke/edge-security.sh <domain> <load-balancer-ip> [upload-path]
#
#   domain             the first of var.domain_names, e.g. www.example.com
#   load-balancer-ip   the load_balancer_ip output of the apply
#   upload-path        optional: the path of an uploaded file, e.g. /wp-content/uploads/2026/10/a.jpg
#
# Requests go to the given IP with curl --resolve, so the test does not depend on DNS, and the TLS
# server name is the domain, as a browser sends it. Each check prints PASS or FAIL with the status and
# the Location header it got. The script exits with 1 if any check fails.
#
# "Blocked" means the request never reached WordPress outside IAP: a 403 from Cloud Armor, or the
# IAP sign-in (a redirect to accounts.google.com, or a 401). Which of them answers can depend on how
# the load balancer normalizes the path, so both count as a pass.
# ==============================================================

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <domain> <load-balancer-ip> [upload-path]" >&2
  exit 2
fi

DOMAIN="$1"
LB_IP="$2"
UPLOAD_PATH="${3:-}"
FAILURES=0

# Status code and Location header of one request. Extra curl options go after the path.
# Sends Accept: text/html, as a browser does: IAP answers browsers with a redirect to the sign-in.
request() {
  local scheme="$1" path="$2"
  shift 2
  local port=443
  [[ "$scheme" == "http" ]] && port=80
  curl -s -o /dev/null --max-time 20 \
    --resolve "${DOMAIN}:${port}:${LB_IP}" \
    -H "Accept: text/html" \
    -w '%{http_code} %{redirect_url}' \
    "$@" \
    "${scheme}://${DOMAIN}${path}"
}

# Same request, with the response body too: the body, a newline, then "status location".
request_with_body() {
  local path="$1"
  curl -s --max-time 20 \
    --resolve "${DOMAIN}:443:${LB_IP}" \
    -H "Accept: text/html" \
    -w '\n%{http_code} %{redirect_url}' \
    "https://${DOMAIN}${path}"
}

report() {
  local result="$1" name="$2" got="$3"
  printf '%-4s  %-58s  %s\n' "$result" "$name" "$got"
  [[ "$result" == "FAIL" ]] && FAILURES=$((FAILURES + 1))
}

# Passes when the status is one of the expected codes (space separated).
expect_status() {
  local name="$1" expected="$2" got="$3"
  local status="${got%% *}"
  if [[ " ${expected} " == *" ${status} "* ]]; then
    report PASS "$name" "$got"
  else
    report FAIL "$name (expected ${expected})" "$got"
  fi
}

# Passes when Cloud Armor or IAP answered: 403, 401, or a redirect to the Google sign-in.
expect_blocked() {
  local name="$1" got="$2"
  local status="${got%% *}" location="${got#* }"
  if [[ "$status" == "403" || "$status" == "401" ]] \
    || [[ "$status" == "302" && "$location" == https://accounts.google.com/* ]]; then
    report PASS "$name" "$got"
  else
    report FAIL "$name (expected 403, 401 or the IAP sign-in)" "$got"
  fi
}

# Passes when WordPress itself answered, which proves the request did not go through IAP:
#   - installed: the status and body WordPress gives a request without its expected parameters,
#     e.g. 400 and "0" from admin-ajax.php without an action (wp-admin/admin-ajax.php);
#   - not installed yet: the 302 to <site>/wp-admin/install.php that WordPress sends for any request
#     before the installation (wp_not_installed() in wp-includes/load.php).
# Neither Cloud Armor (403) nor IAP (302 to accounts.google.com, or 401) answers like that.
expect_wordpress() {
  local name="$1" expected_status="$2" expected_body="$3" response="$4"
  local last_line="${response##*$'\n'}"
  local body="${response%$'\n'*}"
  local status="${last_line%% *}" location="${last_line#* }"
  if [[ "$status" == "$expected_status" && "$body" == "$expected_body" ]]; then
    report PASS "$name" "$status, body '${body}'"
  elif [[ "$status" == "302" && "$location" == "https://${DOMAIN}/wp-admin/install.php" ]]; then
    report PASS "$name (WordPress not installed yet)" "$last_line"
  else
    report FAIL "$name (expected ${expected_status} with body '${expected_body}', or 302 to the installer)" "$status, body '${body:0:40}'"
  fi
}

# Passes when the answer is the IAP sign-in: a redirect to accounts.google.com, or a 401.
expect_iap() {
  local name="$1" got="$2"
  local status="${got%% *}" location="${got#* }"
  if [[ "$status" == "401" ]] || [[ "$status" == "302" && "$location" == https://accounts.google.com/* ]]; then
    report PASS "$name" "$got"
  else
    report FAIL "$name (expected the IAP sign-in)" "$got"
  fi
}

echo "Edge security smoke tests: https://${DOMAIN} at ${LB_IP}"
echo ""

echo "--- Hosts: only the site's domains are served (Cloud Armor, Block unknown hosts)"
# -k: these requests use the IP or another name, which the certificate does not cover.
expect_status "Host: the load balancer IP" "403" \
  "$(curl -sk -o /dev/null --max-time 20 -w '%{http_code} %{redirect_url}' "https://${LB_IP}/")"
expect_status "Host: another domain, TLS name of the site" "403" \
  "$(request https / -H "Host: unknown.example.net")"
got=$(request https /)
if [[ "${got%% *}" == "200" ]] \
  || [[ "${got%% *}" == "302" && "${got#* }" == "https://${DOMAIN}/wp-admin/install.php" ]]; then
  report PASS "Host: the site's domain" "$got"
else
  report FAIL "Host: the site's domain (expected 200, or 302 to the installer)" "$got"
fi

echo ""
echo "--- Admin area and login: only through IAP"
expect_iap "/wp-admin/" "$(request https /wp-admin/)"
expect_iap "/wp-admin" "$(request https /wp-admin)"
expect_iap "/wp-admin/install.php" "$(request https /wp-admin/install.php)"
expect_iap "/wp-login.php" "$(request https /wp-login.php)"

echo ""
echo "--- Path variants that would skip the IAP path rules (Cloud Armor, Block protected paths outside IAP)"
expect_blocked "/wp-login.php/x" "$(request https /wp-login.php/x)"
expect_blocked "//wp-admin/install.php" "$(request https //wp-admin/install.php --path-as-is)"
expect_blocked "/./wp-admin/" "$(request https /./wp-admin/ --path-as-is)"
expect_blocked "/wp-%61dmin/ (encoded a)" "$(request https /wp-%61dmin/)"
expect_blocked "/WP-LOGIN.PHP" "$(request https /WP-LOGIN.PHP)"
expect_blocked "/wp-admin/admin-ajax.php/../install.php" "$(request https /wp-admin/admin-ajax.php/../install.php --path-as-is)"

echo ""
echo "--- Public paths"
# admin-ajax.php is used by the public site, so it must reach WordPress without IAP. Without an action
# WordPress answers 400 with the body "0" (see expect_wordpress).
expect_wordpress "/wp-admin/admin-ajax.php (WordPress, no IAP)" "400" "0" \
  "$(request_with_body /wp-admin/admin-ajax.php)"
expect_status "/health.php" "200" "$(request https /health.php)"
expect_status "/xmlrpc.php (Cloud Armor, Block xmlrpc.php)" "403" "$(request https /xmlrpc.php)"
if [[ -n "$UPLOAD_PATH" ]]; then
  expect_status "Upload ${UPLOAD_PATH} (backend bucket)" "200" "$(request https "$UPLOAD_PATH")"
else
  echo "SKIP  Upload (no upload-path given)"
fi

echo ""
echo "--- HTTP"
got=$(request http /)
if [[ "${got%% *}" == "301" && "${got#* }" == https://${DOMAIN}/* ]]; then
  report PASS "HTTP redirects to HTTPS" "$got"
else
  report FAIL "HTTP redirects to HTTPS (expected 301 to https://${DOMAIN}/)" "$got"
fi

echo ""
if [[ "$FAILURES" -gt 0 ]]; then
  echo "${FAILURES} check(s) failed."
  exit 1
fi
echo "All checks passed."
