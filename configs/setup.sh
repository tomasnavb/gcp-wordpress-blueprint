#!/bin/bash
set -e

# ==============================================================
# Variables — update before running
# ==============================================================
export PROJECT_ID="your-gcp-project-id"
export STATE_BUCKET="${PROJECT_ID}-wordpress-terraform-state"   # passed to terraform init via -backend-config in Cloud Build
export REGION="europe-west1"
export CB_SA="terraform-cloud-build@${PROJECT_ID}.iam.gserviceaccount.com"
export REPO_NAME="your-repo-name"
export REPO_OWNER="your-github-username-or-org"

# ==============================================================
# Enable APIs required before Terraform runs
# The rest are enabled by Terraform via terraform/APIs.tf
# ==============================================================
gcloud services enable compute.googleapis.com --project=${PROJECT_ID}

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
# Cloud Build service account
# ==============================================================
gcloud iam service-accounts create terraform-cloud-build \
  --project=${PROJECT_ID} \
  --display-name="Terraform Cloud Build SA" \
  --description="Service account for the Terraform CI/CD pipeline via Cloud Build"

echo "Waiting for service account to propagate..."
sleep 15

# ==============================================================
# Project-level IAM bindings
# Adjust this list if your project manages additional resource types
# ==============================================================

# Compute Engine — VMs, MIGs, instance templates, networks, firewalls, LBs, autoscalers
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/compute.admin"

# Cloud SQL — instances, databases, users
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/cloudsql.admin"

# Cloud Functions v2
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/cloudfunctions.admin"

# Cloud Run — required because Cloud Functions v2 runs on top of Cloud Run
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/run.admin"

# Cloud Storage — application buckets (backups, function scripts)
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/storage.admin"

# Secret Manager — Terraform creates and manages WordPress secrets
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/secretmanager.admin"

# Cloud Scheduler — jobs that invoke the backup function
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/cloudscheduler.admin"

# Service Networking — required to manage Private Service Access (Cloud SQL VPC peering)
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/servicenetworking.networksAdmin"

# IAM — Terraform creates service accounts and assigns roles to resources
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/iam.serviceAccountAdmin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/resourcemanager.projectIamAdmin"

# ==============================================================
# Bucket-level IAM binding — scoped to the state bucket only
# ==============================================================
gcloud storage buckets add-iam-policy-binding gs://${STATE_BUCKET} \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/storage.objectAdmin"

echo "Service account ${CB_SA} created and configured successfully."

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
# Builds a new golden image and registers it under the wordpress-golden image family.
# NOT triggered on PRs — Packer creates real GCP resources and takes 10-15 minutes.
gcloud builds triggers create github \
  --project=${PROJECT_ID} \
  --name="packer-build" \
  --repo-name="${REPO_NAME}" \
  --repo-owner="${REPO_OWNER}" \
  --branch-pattern="^main$" \
  --included-files="packer/**" \
  --build-config="cloudbuild/packer.yaml" \
  --substitutions="_PROJECT_ID=${PROJECT_ID},_ZONE=europe-west1-b,_NETWORK=wordpress-mgmt-vpc,_SUBNETWORK=wordpress-mgmt-subnet" \
  --service-account="projects/${PROJECT_ID}/serviceAccounts/${CB_SA}"

# Plan trigger — fires automatically on every PR targeting main.
# Runs terraform-plan.yaml: init, fmt, validate, plan, destructive change check, artifact upload.
gcloud builds triggers create github \
  --project=${PROJECT_ID} \
  --name="terraform-plan" \
  --repo-name="${REPO_NAME}" \
  --repo-owner="${REPO_OWNER}" \
  --pull-request-pattern="^main$" \
  --build-config="cloudbuild/terraform-plan.yaml" \
  --substitutions="_PROJECT_ID=${PROJECT_ID},_STATE_BUCKET=${STATE_BUCKET},_ALLOW_DESTRUCTIVE_CHANGES=false" \
  --service-account="projects/${PROJECT_ID}/serviceAccounts/${CB_SA}"

# Apply trigger — triggered manually after reviewing and approving the plan.
# Requires --require-approval so no one can run it without explicit approval.
# Override _PLAN_BUILD_ID with the BUILD_ID from the plan run you want to apply.
gcloud beta builds triggers create manual \
  --project=${PROJECT_ID} \
  --name="terraform-apply" \
  --repo="https://github.com/${REPO_OWNER}/${REPO_NAME}" \
  --repo-type="GITHUB" \
  --branch="main" \
  --build-config="cloudbuild/terraform-apply.yaml" \
  --substitutions="_PROJECT_ID=${PROJECT_ID},_STATE_BUCKET=${STATE_BUCKET},_PLAN_BUILD_ID=REPLACE_WITH_PLAN_BUILD_ID" \
  --service-account="projects/${PROJECT_ID}/serviceAccounts/${CB_SA}" \
  --require-approval

echo "Triggers created successfully."
echo ""
echo "To apply a reviewed plan, run:"
echo "  gcloud beta builds triggers run terraform-apply \\"
echo "    --project=${PROJECT_ID} \\"
echo "    --branch=main \\"
echo "    --substitutions=_PLAN_BUILD_ID=<BUILD_ID_FROM_PLAN>"
