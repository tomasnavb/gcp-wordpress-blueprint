#!/bin/bash
set -e

# ==============================================================
# Variables
#
# Export them in your shell before running, so this file is never edited with real values:
#   export PROJECT_ID="my-project" REPO_NAME="my-repo" REPO_OWNER="my-user" IAP_USER_EMAIL="me@example.com"
# A variable that is not exported keeps the placeholder below, and the script stops.
# ==============================================================
export PROJECT_ID="${PROJECT_ID:-your-gcp-project-id}"
export ENVIRONMENT="${ENVIRONMENT:-prod}"   # environment in terraform/terraform.tfvars; part of the names below
export STATE_BUCKET="${PROJECT_ID}-tfstate"   # passed to terraform init via -backend-config in Cloud Build
export SOURCE_BUCKET="${PROJECT_ID}_cloudbuild"   # where gcloud builds submit uploads the source (fixed by gcloud)
export REGION="europe-west1"
# Pipeline service accounts, one per job (created below):
#   plan   - read-only, runs the plans of pull requests and of main. A plan runs code from the PR.
#   apply  - write roles, runs only the manual, approved apply.
#   packer - builds the golden image.
export PLAN_SA="terraform-plan-sa@${PROJECT_ID}.iam.gserviceaccount.com"
export APPLY_SA="terraform-apply-sa@${PROJECT_ID}.iam.gserviceaccount.com"
export PACKER_SA="packer-build-sa@${PROJECT_ID}.iam.gserviceaccount.com"
export REPO_NAME="${REPO_NAME:-your-repo-name}"
export REPO_OWNER="${REPO_OWNER:-your-github-username-or-org}"
export IAP_USER_EMAIL="${IAP_USER_EMAIL:-your-email-address}"   # Google account granted SSH access through IAP

# Static IP for the load balancer. Must match lb_use_reserved_ip in terraform/terraform.tfvars.
#   true  — reserve a global IP here, outside Terraform. It survives terraform destroy, so the
#           DNS record is set once. It is billed while no load balancer is using it.
#   false — skip. Terraform creates the IP with the load balancer and destroys it with it.
export RESERVE_LB_IP="${RESERVE_LB_IP:-true}"
export LB_IP_NAME="wp-blueprint-lb-ip-${ENVIRONMENT}"   # name the load balancer module looks up; do not change one without the other

# Stop before creating anything if a required variable still has its placeholder.
for var_name in PROJECT_ID REPO_NAME REPO_OWNER IAP_USER_EMAIL; do
  if [[ "${!var_name}" == your-* ]]; then
    echo "ERROR: ${var_name} is not set. Export it before running this script." >&2
    exit 1
  fi
done

# ==============================================================
# Enable APIs required before Terraform runs
# The rest are enabled by Terraform via terraform/APIs.tf
#
# serviceusage         — Terraform uses it to enable every other API, so it cannot enable it itself
# cloudresourcemanager — project-level IAM bindings (this script and Terraform)
# iam                  — service account creation (this script and Terraform)
# cloudbuild           — triggers created at the end of this script
# compute              — first Packer build runs before the first terraform apply
# ==============================================================
gcloud services enable \
  serviceusage.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  cloudbuild.googleapis.com \
  compute.googleapis.com \
  --project=${PROJECT_ID}

# ==============================================================
# Terraform state bucket
# ==============================================================
gcloud storage buckets create gs://${STATE_BUCKET} \
  --project=${PROJECT_ID} \
  --location=${REGION} \
  --uniform-bucket-level-access

# Versioning — allows restoring a previous tfstate if an apply corrupts it
gcloud storage buckets update gs://${STATE_BUCKET} \
  --versioning

# Lifecycle — deletes plan artifacts after 30 days
# Plans are stored at gs://bucket/plans/BUILD_ID/tfplan
# Without this rule they accumulate indefinitely and generate unnecessary cost
cat > /tmp/lifecycle.json << 'EOF'
{
  "rule": [{
    "action": {"type": "Delete"},
    "condition": {
      "age": 30,
      "matchesPrefix": ["plans/"]
    }
  }]
}
EOF

gcloud storage buckets update gs://${STATE_BUCKET} \
  --lifecycle-file=/tmp/lifecycle.json

echo "Bucket gs://${STATE_BUCKET} created successfully."

# ==============================================================
# Cloud Build source bucket
# gcloud builds submit (the first deploy, Steps 6 to 8 of the README) uploads the local directory
# to gs://<project_id>_cloudbuild, and the build starts by reading it with the service account it
# runs as. gcloud creates the bucket on the first submit if it does not exist; it is created here so
# that the pipeline service accounts can be granted read access on it below. Triggers do not use it:
# they fetch the source from GitHub.
# ==============================================================
if ! gcloud storage buckets describe gs://${SOURCE_BUCKET} --project=${PROJECT_ID} >/dev/null 2>&1; then
  gcloud storage buckets create gs://${SOURCE_BUCKET} \
    --project=${PROJECT_ID} \
    --location=${REGION} \
    --uniform-bucket-level-access
fi
echo "Bucket gs://${SOURCE_BUCKET} ready."

# ==============================================================
# Static IP for the load balancer (optional, see RESERVE_LB_IP above)
# Reserved here and not in Terraform so that terraform destroy does not release it.
# ==============================================================
if [ "${RESERVE_LB_IP}" = "true" ]; then
  gcloud compute addresses create ${LB_IP_NAME} \
    --project=${PROJECT_ID} \
    --global \
    --ip-version=IPV4

  LB_IP=$(gcloud compute addresses describe ${LB_IP_NAME} \
    --project=${PROJECT_ID} \
    --global \
    --format="value(address)")

  echo ""
  echo "Load balancer IP reserved: ${LB_IP}"
  echo "Create a DNS A record for your domain pointing to this address."
  echo "The managed SSL certificate is only issued once that record resolves."
  echo "To release the IP and stop paying for it when it is no longer needed:"
  echo "  gcloud compute addresses delete ${LB_IP_NAME} --project=${PROJECT_ID} --global"
  echo ""
else
  echo "RESERVE_LB_IP is not 'true'. Terraform will create the load balancer IP (lb_use_reserved_ip must be false)."
fi

# ==============================================================
# Pipeline service accounts
# ==============================================================
gcloud iam service-accounts create terraform-plan-sa \
  --project=${PROJECT_ID} \
  --display-name="Terraform plan SA" \
  --description="Read-only. Runs terraform plan for pull requests and for main"

gcloud iam service-accounts create terraform-apply-sa \
  --project=${PROJECT_ID} \
  --display-name="Terraform apply SA" \
  --description="Runs terraform apply of an approved plan"

gcloud iam service-accounts create packer-build-sa \
  --project=${PROJECT_ID} \
  --display-name="Packer build SA" \
  --description="Builds the golden image with Packer"

echo "Waiting for the service accounts to propagate..."
sleep 15

# Grants project-level roles to a service account: grant_roles <email> <role>...
grant_roles() {
  local sa=$1
  shift
  for role in "$@"; do
    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
      --member="serviceAccount:${sa}" \
      --role="${role}" \
      --condition=None \
      --quiet >/dev/null
    echo "  ${sa}: ${role}"
  done
}

# Plan: read-only.
#   viewer                - refresh: read the real state of every resource
#   iam.securityReviewer  - read IAM policies, which viewer does not include (refresh of the bindings)
#   logging.logWriter     - build logs (CLOUD_LOGGING_ONLY)
# Terraform adds what the plan reads beyond that, scoped to the resource (terraform/IAM.tf, 3.7): the
# database password secret, read during plan by an ephemeral block, and the objects it manages.
grant_roles "${PLAN_SA}" \
  roles/viewer \
  roles/iam.securityReviewer \
  roles/logging.logWriter

# Apply: creates and changes every resource of the project. Adjust this list if the project
# manages additional resource types.
grant_roles "${APPLY_SA}" \
  roles/serviceusage.serviceUsageAdmin \
  roles/compute.admin \
  roles/cloudsql.admin \
  roles/cloudfunctions.admin \
  roles/run.admin \
  roles/storage.admin \
  roles/secretmanager.admin \
  roles/cloudscheduler.admin \
  roles/servicenetworking.networksAdmin \
  roles/logging.logWriter \
  roles/iam.roleAdmin \
  roles/iam.serviceAccountAdmin \
  roles/iam.serviceAccountUser \
  roles/resourcemanager.projectIamAdmin
# What each one is for:
#   serviceUsageAdmin       - Terraform enables the APIs listed in terraform/APIs.tf
#   compute.admin           - VMs, MIGs, templates, networks, firewalls, load balancer, autoscaler
#   cloudsql.admin          - instance, database, user
#   cloudfunctions.admin    - backup function (v2)
#   run.admin               - Cloud Functions v2 runs on Cloud Run
#   storage.admin           - application buckets
#   secretmanager.admin     - WordPress secrets
#   cloudscheduler.admin    - backup job
#   networksAdmin           - Private Service Access (Cloud SQL private IP)
#   logging.logWriter       - build logs (CLOUD_LOGGING_ONLY)
#   iam.roleAdmin           - custom role of the backup function
#   serviceAccountAdmin     - workload service accounts
#   serviceAccountUser      - attach those service accounts to VMs and the function
#   projectIamAdmin         - project-level IAM bindings

# Packer: create the temporary build VM and the image, and reach the VM through IAP. The VM runs
# without a service account (packer/wordpress.pkr.hcl), so iam.serviceAccountUser is not needed.
grant_roles "${PACKER_SA}" \
  roles/compute.instanceAdmin.v1 \
  roles/iap.tunnelResourceAccessor \
  roles/logging.logWriter

# ==============================================================
# Bucket-level IAM bindings — scoped to the state and source buckets only
# Plan and apply both write it: the state lock, and the saved plans under plans/.
# ==============================================================
for sa in "${PLAN_SA}" "${APPLY_SA}"; do
  gcloud storage buckets add-iam-policy-binding gs://${STATE_BUCKET} \
    --member="serviceAccount:${sa}" \
    --role="roles/storage.objectAdmin" >/dev/null
  echo "  ${sa}: roles/storage.objectAdmin on gs://${STATE_BUCKET}"
done

# Read the source that gcloud builds submit uploads. Only plan and Packer need it: apply already
# reads every bucket with roles/storage.admin.
for sa in "${PLAN_SA}" "${PACKER_SA}"; do
  gcloud storage buckets add-iam-policy-binding gs://${SOURCE_BUCKET} \
    --member="serviceAccount:${sa}" \
    --role="roles/storage.objectViewer" >/dev/null
  echo "  ${sa}: roles/storage.objectViewer on gs://${SOURCE_BUCKET}"
done

echo "Pipeline service accounts created and configured successfully."

# ==============================================================
# Cloud Build triggers
#
# PREREQUISITE: the GitHub repository must be connected to Cloud Build
# before running this section. Do it manually from the GCP console:
#   Cloud Build → Triggers → Connect Repository → GitHub
#
# This step requires OAuth authorization and cannot be done via gcloud.
# ==============================================================
read -r -p "Have you already connected the GitHub repository in the Cloud Build console? (y/N): " REPLY
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
  echo ""
  echo "Skipping trigger creation."
  echo "Once the repository is connected, re-run this script from the trigger section"
  echo "or create the triggers manually with the gcloud commands below."
  exit 0
fi

# Packer trigger — fires on push to main only when packer/ files change.
# Builds a new golden image and registers it under the wp-blueprint-web image family.
# NOT triggered on PRs — Packer creates real GCP resources and takes about 5 minutes.
# _USE_IAP=true: the build VM runs in the build subnet, has no external IP, and Packer connects through
# an IAP tunnel. That subnet is created by Terraform, so the trigger only works after the first apply.
gcloud builds triggers create github \
  --project=${PROJECT_ID} \
  --name="wp-blueprint-image-build-${ENVIRONMENT}" \
  --repo-name="${REPO_NAME}" \
  --repo-owner="${REPO_OWNER}" \
  --branch-pattern="^main$" \
  --included-files="packer/**" \
  --build-config="cloudbuild/packer.yaml" \
  --substitutions="_PROJECT_ID=${PROJECT_ID},_ZONE=europe-west1-b,_ENVIRONMENT=${ENVIRONMENT},_USE_IAP=true" \
  --service-account="projects/${PROJECT_ID}/serviceAccounts/${PACKER_SA}"

# PR plan trigger — fires automatically on every PR targeting main.
# Runs terraform-plan.yaml: init, fmt, validate, plan, destructive change report.
# Review only: _SAVE_PLAN=false, so the plan is not uploaded and cannot be applied.
gcloud builds triggers create github \
  --project=${PROJECT_ID} \
  --name="wp-blueprint-tf-plan-pr-${ENVIRONMENT}" \
  --repo-name="${REPO_NAME}" \
  --repo-owner="${REPO_OWNER}" \
  --pull-request-pattern="^main$" \
  --build-config="cloudbuild/terraform-plan.yaml" \
  --substitutions="_PROJECT_ID=${PROJECT_ID},_STATE_BUCKET=${STATE_BUCKET},_IAP_USER_EMAIL=${IAP_USER_EMAIL},_SAVE_PLAN=false" \
  --service-account="projects/${PROJECT_ID}/serviceAccounts/${PLAN_SA}"

# Main plan trigger — fires on push to main (a merged PR) when terraform/ files change.
# Same pipeline with _SAVE_PLAN=true: the plan is uploaded to gs://STATE_BUCKET/plans/BUILD_ID/.
# This is the only plan the apply trigger is meant to use, so what is deployed always comes from main.
gcloud builds triggers create github \
  --project=${PROJECT_ID} \
  --name="wp-blueprint-tf-plan-main-${ENVIRONMENT}" \
  --repo-name="${REPO_NAME}" \
  --repo-owner="${REPO_OWNER}" \
  --branch-pattern="^main$" \
  --included-files="terraform/**" \
  --build-config="cloudbuild/terraform-plan.yaml" \
  --substitutions="_PROJECT_ID=${PROJECT_ID},_STATE_BUCKET=${STATE_BUCKET},_IAP_USER_EMAIL=${IAP_USER_EMAIL},_SAVE_PLAN=true" \
  --service-account="projects/${PROJECT_ID}/serviceAccounts/${PLAN_SA}"

# Apply trigger — triggered manually after reviewing the plan generated on main.
# Requires --require-approval so no one can run it without explicit approval.
# Override _PLAN_BUILD_ID with the BUILD_ID of the plan-main trigger run you want to apply.
# A plan with destructive changes is rejected unless _ALLOW_DESTRUCTIVE=true is passed at run time.
gcloud beta builds triggers create manual \
  --project=${PROJECT_ID} \
  --name="wp-blueprint-tf-apply-${ENVIRONMENT}" \
  --repo="https://github.com/${REPO_OWNER}/${REPO_NAME}" \
  --repo-type="GITHUB" \
  --branch="main" \
  --build-config="cloudbuild/terraform-apply.yaml" \
  --substitutions="_PROJECT_ID=${PROJECT_ID},_STATE_BUCKET=${STATE_BUCKET},_PLAN_BUILD_ID=REPLACE_WITH_PLAN_BUILD_ID,_ALLOW_DESTRUCTIVE=false" \
  --service-account="projects/${PROJECT_ID}/serviceAccounts/${APPLY_SA}" \
  --require-approval

echo "Triggers created successfully."
echo ""
echo "To apply the plan generated by wp-blueprint-tf-plan-main-${ENVIRONMENT}, run:"
echo "  gcloud beta builds triggers run wp-blueprint-tf-apply-${ENVIRONMENT} \\"
echo "    --project=${PROJECT_ID} \\"
echo "    --branch=main \\"
echo "    --substitutions=_PLAN_BUILD_ID=<BUILD_ID_FROM_PLAN>"
echo ""
echo "If the plan has destructive changes, add _ALLOW_DESTRUCTIVE=true to the substitutions."
