#!/bin/bash
set -e

# ==============================================================
# Helper commands for tearing the environment down.
#
# This script does NOT run terraform destroy. It runs the gcloud commands that
# terraform destroy needs around it, and is meant to be run from Cloud Shell:
#
#   1. Before terraform destroy:
#        bash configs/destroy.sh empty-buckets
#      Both buckets keep force_destroy = false on purpose, and their content is
#      created by Cloud SQL (exports) and by WordPress (uploads, in the uploads bucket), not by
#      Terraform, so terraform destroy refuses to delete them while they hold
#      objects.
#
#   2. Only if terraform destroy stops on the Cloud SQL network connection, or on
#      the reserved range or the VPC because of it:
#        bash configs/destroy.sh delete-peering
#      then run terraform destroy again. The connection has
#      deletion_policy = "ABANDON", so this should not be needed.
#
# Export PROJECT_ID before running. Both commands ask to type the project ID
# before changing anything.
# ==============================================================

export PROJECT_ID="${PROJECT_ID:-your-gcp-project-id}"

export ENVIRONMENT="${ENVIRONMENT:-prod}"   # environment in terraform/terraform.tfvars

# Names must match terraform/locals.tf (naming convention): change them there and here together.
BACKUPS_BUCKET="${PROJECT_ID}-db-backups"
UPLOADS_BUCKET="${PROJECT_ID}-uploads"
PROD_VPC="wp-blueprint-vpc-${ENVIRONMENT}"
PEERING_NAME="servicenetworking-googleapis-com"

usage() {
  echo "Usage: bash configs/destroy.sh <empty-buckets|delete-peering>" >&2
  exit 1
}

if [[ "${PROJECT_ID}" == your-* ]]; then
  echo "ERROR: PROJECT_ID is not set. Export it before running this script." >&2
  exit 1
fi

confirm() {
  echo ""
  echo "$1"
  read -r -p "Type the project ID (${PROJECT_ID}) to continue: " REPLY
  if [[ "${REPLY}" != "${PROJECT_ID}" ]]; then
    echo "Confirmation does not match. Nothing was changed." >&2
    exit 1
  fi
}

# Deletes every object of a bucket, all versions included. Skips a bucket that
# does not exist or is already empty.
empty_bucket() {
  local bucket=$1

  if ! gcloud storage buckets describe "gs://${bucket}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    echo "gs://${bucket} does not exist. Skipping."
    return 0
  fi

  if [[ -z "$(gcloud storage ls --all-versions "gs://${bucket}/**" --project="${PROJECT_ID}" 2>/dev/null | head -n 1)" ]]; then
    echo "gs://${bucket} is already empty. Skipping."
    return 0
  fi

  echo "Emptying gs://${bucket}..."
  gcloud storage rm --recursive --all-versions "gs://${bucket}/**" --project="${PROJECT_ID}"
}

case "$1" in
  empty-buckets)
    confirm "This deletes, for good, every object in gs://${BACKUPS_BUCKET} (database exports) and gs://${UPLOADS_BUCKET} (WordPress uploads), all versions included."
    empty_bucket "${BACKUPS_BUCKET}"
    empty_bucket "${UPLOADS_BUCKET}"
    echo ""
    echo "Buckets emptied. Now run terraform destroy (see the Destroy section of the README)."
    ;;

  delete-peering)
    confirm "This deletes the peering ${PEERING_NAME} from ${PROD_VPC}: the private connection of Cloud SQL, from the VPC side."
    gcloud compute networks peerings delete "${PEERING_NAME}" \
      --network="${PROD_VPC}" \
      --project="${PROJECT_ID}"
    echo ""
    echo "Peering deleted. Run terraform destroy again."
    ;;

  *)
    usage
    ;;
esac
