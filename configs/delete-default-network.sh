#!/bin/bash
set -e

# ==============================================================
# Deletes the default network of the project and its firewall rules.
#
# The default network is only used by the first image build, which runs before the production VPC
# exists (_USE_IAP=false: the build VM gets an external IP, and default-allow-ssh opens port 22 to
# the internet). Every later build runs in the build subnet of the production VPC, through IAP.
# Once the first terraform apply has finished, the default network has no use left and only adds
# open firewall rules to the project.
#
# Optional, run once from Cloud Shell after the first apply:
#   bash configs/delete-default-network.sh
#
# After this, _USE_IAP=false no longer works in this project. A new project gets its own
# default network again.
#
# Export PROJECT_ID before running. It asks to type the project ID before changing anything.
# ==============================================================

export PROJECT_ID="${PROJECT_ID:-your-gcp-project-id}"
NETWORK="default"

if [[ "${PROJECT_ID}" == your-* ]]; then
  echo "ERROR: PROJECT_ID is not set. Export it before running this script." >&2
  exit 1
fi

if ! gcloud compute networks describe "${NETWORK}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Network ${NETWORK} does not exist in ${PROJECT_ID}. Nothing to delete."
  exit 0
fi

# A network cannot be deleted while firewall rules still reference it.
RULES=$(gcloud compute firewall-rules list \
  --project="${PROJECT_ID}" \
  --filter="network~/networks/${NETWORK}$" \
  --format="value(name)")

echo ""
echo "This deletes the network ${NETWORK} of ${PROJECT_ID} and its firewall rules:"
if [[ -n "${RULES}" ]]; then
  echo "${RULES}" | sed 's/^/  - /'
else
  echo "  (no firewall rules)"
fi
read -r -p "Type the project ID (${PROJECT_ID}) to continue: " REPLY
if [[ "${REPLY}" != "${PROJECT_ID}" ]]; then
  echo "Confirmation does not match. Nothing was changed." >&2
  exit 1
fi

if [[ -n "${RULES}" ]]; then
  # One name per line; word splitting passes them as separate arguments.
  # shellcheck disable=SC2086
  gcloud compute firewall-rules delete ${RULES} --project="${PROJECT_ID}" --quiet
fi

gcloud compute networks delete "${NETWORK}" --project="${PROJECT_ID}" --quiet

echo ""
echo "Network ${NETWORK} deleted. Image builds keep running in the build subnet through IAP."
