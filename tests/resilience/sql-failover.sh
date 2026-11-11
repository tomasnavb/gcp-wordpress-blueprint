#!/bin/bash
set -uo pipefail

# ==============================================================
# Resilience test: a manual failover of the Cloud SQL instance, and how long the site is down.
# NOT read-only: it moves the primary of the instance to its standby zone. Run it only on a test
# deploy, never while the site has real traffic. It asks for the instance name before acting.
#
# Usage (see docs/test-procedure.md, level 4):
#   bash tests/resilience/sql-failover.sh <project-id> <domain> <load-balancer-ip> [instance]
#
#   project-id         the project of the deploy
#   domain             the first of var.domain_names, e.g. www.example.com
#   load-balancer-ip   the load_balancer_ip output of the apply
#   instance           optional, the Cloud SQL instance; default wp-blueprint-db-prod
#
# Needs gcloud, signed in with permission to fail over the instance (roles/cloudsql.editor), and curl.
#
# How it measures: it requests the home page once a second, with a query string that changes on
# every request so no cache answers for WordPress. The home page needs the database, so it answers
# 500 while the database is unreachable. /health.php does not touch the database, so the instances
# stay healthy and the load balancer keeps sending them traffic: what fails is WordPress, not the
# load balancer. The downtime is from the first failed request to the first good one after the last
# failure.
#
# What it checks after the failover:
#   - the primary zone changed to the zone the standby was in;
#   - the private IP is the same, so the instances reconnect without any change.
# The script exits with 1 if a check fails or the failover does not finish.
# ==============================================================

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <project-id> <domain> <load-balancer-ip> [instance]" >&2
  exit 2
fi

PROJECT_ID="$1"
DOMAIN="$2"
LB_IP="$3"
INSTANCE="${4:-wp-blueprint-db-prod}"

POLL_INTERVAL_S=1   # Seconds between requests
REQUEST_TIMEOUT_S=3 # A request slower than this counts as failed
RECOVERED_AFTER=10  # Good requests in a row, after the operation is done, to stop
MAX_DURATION_S=600  # Stop measuring after this long, whatever the state
FAILURES=0

now_ms() { date +%s%3N; }

# Status code of the home page. Requests go to the given IP with curl --resolve, as in the smoke tests.
home_status() {
  curl -s -o /dev/null --max-time "$REQUEST_TIMEOUT_S" \
    --resolve "${DOMAIN}:443:${LB_IP}" \
    -w '%{http_code}' \
    "https://${DOMAIN}/?failover-test=$(now_ms)"
}

# WordPress answers 200 when installed, and 302 to the installer before that. Both need the database.
is_up() { [[ "$1" == "200" || "$1" == "302" ]]; }

check() {
  local result="$1" name="$2" detail="$3"
  printf '%-4s  %-40s  %s\n' "$result" "$name" "$detail"
  [[ "$result" == "FAIL" ]] && FAILURES=$((FAILURES + 1))
  return 0
}

describe() {
  gcloud sql instances describe "$INSTANCE" --project="$PROJECT_ID" --format="value($1)"
}

echo "Cloud SQL failover test: ${INSTANCE} in ${PROJECT_ID}, site https://${DOMAIN} at ${LB_IP}"
echo ""

# --- Prechecks: nothing is changed if any of them fails
STATE=$(describe state) || { echo "Cannot describe ${INSTANCE} in ${PROJECT_ID}." >&2; exit 2; }
AVAILABILITY=$(describe settings.availabilityType)
ZONE_BEFORE=$(describe gceZone)
STANDBY_ZONE=$(describe secondaryGceZone)
# The instance has only a private IP (ipv4_enabled = false), so the first address is that one.
IP_BEFORE=$(describe "ipAddresses[0].ipAddress")
STATUS_BEFORE=$(home_status)

echo "State: ${STATE}, availability: ${AVAILABILITY}"
echo "Primary zone: ${ZONE_BEFORE}, standby zone: ${STANDBY_ZONE}, private IP: ${IP_BEFORE}"
echo "Home page: ${STATUS_BEFORE}"
echo ""

if [[ "$STATE" != "RUNNABLE" ]]; then
  echo "The instance is not RUNNABLE. Nothing was changed." >&2
  exit 2
fi
if [[ "$AVAILABILITY" != "REGIONAL" ]]; then
  echo "The instance is not REGIONAL: it has no standby to fail over to. Nothing was changed." >&2
  exit 2
fi
if ! is_up "$STATUS_BEFORE"; then
  echo "The home page does not answer 200 or 302 before the failover. Nothing was changed." >&2
  exit 2
fi

read -r -p "Type the instance name (${INSTANCE}) to fail it over: " CONFIRM
if [[ "$CONFIRM" != "$INSTANCE" ]]; then
  echo "Not confirmed. Nothing was changed." >&2
  exit 2
fi

# --- Failover
OPERATION=$(gcloud sql instances failover "$INSTANCE" --project="$PROJECT_ID" \
  --async --quiet --format="value(name)") || { echo "The failover request failed." >&2; exit 1; }
START_MS=$(now_ms)
echo "Failover requested, operation ${OPERATION}. Measuring..."

FIRST_DOWN_MS=""
LAST_DOWN_MS=""
RECOVERED_MS=""
FAILED_REQUESTS=0
GOOD_IN_A_ROW=0
OPERATION_STATUS="PENDING"
LAST_OPERATION_CHECK_MS=0
declare -A STATUS_COUNT

while true; do
  NOW=$(now_ms)
  STATUS=$(home_status)
  STATUS_COUNT[$STATUS]=$(( ${STATUS_COUNT[$STATUS]:-0} + 1 ))

  if is_up "$STATUS"; then
    GOOD_IN_A_ROW=$((GOOD_IN_A_ROW + 1))
    [[ -n "$LAST_DOWN_MS" && -z "$RECOVERED_MS" ]] && RECOVERED_MS="$NOW"
  else
    FAILED_REQUESTS=$((FAILED_REQUESTS + 1))
    GOOD_IN_A_ROW=0
    [[ -z "$FIRST_DOWN_MS" ]] && FIRST_DOWN_MS="$NOW"
    LAST_DOWN_MS="$NOW"
    RECOVERED_MS=""
    printf '  +%5.1fs  %s\n' "$(( NOW - START_MS ))e-3" "$STATUS"
  fi

  # The operation status is a gcloud call, slower than a request: read it every 10 seconds.
  if (( NOW - LAST_OPERATION_CHECK_MS >= 10000 )); then
    OPERATION_STATUS=$(gcloud sql operations describe "$OPERATION" --project="$PROJECT_ID" \
      --format="value(status)")
    LAST_OPERATION_CHECK_MS="$NOW"
  fi

  if [[ "$OPERATION_STATUS" == "DONE" && "$GOOD_IN_A_ROW" -ge "$RECOVERED_AFTER" ]]; then
    break
  fi
  if (( NOW - START_MS >= MAX_DURATION_S * 1000 )); then
    echo "Stopped after ${MAX_DURATION_S} s: operation ${OPERATION_STATUS}, ${GOOD_IN_A_ROW} good requests in a row."
    break
  fi
  sleep "$POLL_INTERVAL_S"
done

# --- Results
echo ""
gcloud sql operations describe "$OPERATION" --project="$PROJECT_ID" \
  --format="table(operationType, status, startTime, endTime, error.errors[0].code)"
echo ""

STATUSES=""
for code in "${!STATUS_COUNT[@]}"; do STATUSES+="${code}: ${STATUS_COUNT[$code]}  "; done
echo "Responses: ${STATUSES}"

if [[ -z "$FIRST_DOWN_MS" ]]; then
  echo "Downtime: none measured (no failed request at ${POLL_INTERVAL_S} s intervals)."
else
  DOWNTIME_MS=$(( ${RECOVERED_MS:-$(now_ms)} - FIRST_DOWN_MS ))
  printf 'Downtime: %.1f s, from +%.1f s to +%.1f s after the request; %d failed requests.\n' \
    "${DOWNTIME_MS}e-3" "$(( FIRST_DOWN_MS - START_MS ))e-3" \
    "$(( ${RECOVERED_MS:-$(now_ms)} - START_MS ))e-3" "$FAILED_REQUESTS"
fi
echo ""

ZONE_AFTER=$(describe gceZone)
IP_AFTER=$(describe "ipAddresses[0].ipAddress")

[[ "$OPERATION_STATUS" == "DONE" ]] \
  && check PASS "Failover operation finished" "$OPERATION_STATUS" \
  || check FAIL "Failover operation finished" "$OPERATION_STATUS"
[[ "$ZONE_AFTER" == "$STANDBY_ZONE" ]] \
  && check PASS "Primary moved to the standby zone" "${ZONE_BEFORE} -> ${ZONE_AFTER}" \
  || check FAIL "Primary moved to the standby zone" "${ZONE_BEFORE} -> ${ZONE_AFTER}, expected ${STANDBY_ZONE}"
[[ "$IP_AFTER" == "$IP_BEFORE" ]] \
  && check PASS "Private IP unchanged" "${IP_AFTER}" \
  || check FAIL "Private IP unchanged" "${IP_BEFORE} -> ${IP_AFTER}"
[[ -n "$RECOVERED_MS" || -z "$FIRST_DOWN_MS" ]] \
  && check PASS "Site answering again" "${GOOD_IN_A_ROW} good requests in a row" \
  || check FAIL "Site answering again" "last status ${STATUS}"

echo ""
if [[ "$FAILURES" -gt 0 ]]; then
  echo "${FAILURES} check(s) failed."
  exit 1
fi
echo "All checks passed."
