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
export STATE_BUCKET="${PROJECT_ID}-wordpress-terraform-state"   # passed to terraform init via -backend-config in Cloud Build
export REGION="europe-west1"
export CB_SA="terraform-cloud-build@${PROJECT_ID}.iam.gserviceaccount.com"
export REPO_NAME="${REPO_NAME:-your-repo-name}"
export REPO_OWNER="${REPO_OWNER:-your-github-username-or-org}"
export IAP_USER_EMAIL="${IAP_USER_EMAIL:-your-email-address}"   # Google account granted SSH access through IAP

# Static IP for the load balancer. Must match lb_use_reserved_ip in terraform/terraform.tfvars.
#   true  — reserve a global IP here, outside Terraform. It survives terraform destroy, so the
#           DNS record is set once. It is billed while no load balancer is using it.
#   false — skip. Terraform creates the IP with the load balancer and destroys it with it.
export RESERVE_LB_IP="${RESERVE_LB_IP:-true}"
export LB_IP_NAME="wordpress-prod-lb-ip-global-external-lb"   # name Terraform looks up; do not change one without the other

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

# Service Usage — Terraform enables the project APIs listed in terraform/APIs.tf
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/serviceusage.serviceUsageAdmin"

# Compute Engine — VMs, MIGs, instance templates, networks, firewalls, LBs, autoscalers
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/compute.admin"

# IAP — Packer reaches its temporary build VM through an IAP tunnel (no external IP)
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/iap.tunnelResourceAccessor"

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

# Cloud Logging — required to write build logs when using CLOUD_LOGGING_ONLY
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/logging.logWriter"

# IAM — custom role management (required for google_project_iam_custom_role resources)
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/iam.roleAdmin"

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
# _USE_IAP=true: the build VM has no external IP and Packer connects through an IAP tunnel.
# This needs the management VPC, so the trigger only works after the first terraform apply.
gcloud builds triggers create github \
  --project=${PROJECT_ID} \
  --name="packer-build" \
  --repo-name="${REPO_NAME}" \
  --repo-owner="${REPO_OWNER}" \
  --branch-pattern="^main$" \
  --included-files="packer/**" \
  --build-config="cloudbuild/packer.yaml" \
  --substitutions="_PROJECT_ID=${PROJECT_ID},_ZONE=europe-west1-b,_NETWORK=wordpress-mgmt-vpc,_SUBNETWORK=wordpress-mgmt-subnet,_USE_IAP=true" \
  --service-account="projects/${PROJECT_ID}/serviceAccounts/${CB_SA}"

# PR plan trigger — fires automatically on every PR targeting main.
# Runs terraform-plan.yaml: init, fmt, validate, plan, destructive change report.
# Review only: _SAVE_PLAN=false, so the plan is not uploaded and cannot be applied.
gcloud builds triggers create github \
  --project=${PROJECT_ID} \
  --name="terraform-plan-pr" \
  --repo-name="${REPO_NAME}" \
  --repo-owner="${REPO_OWNER}" \
  --pull-request-pattern="^main$" \
  --build-config="cloudbuild/terraform-plan.yaml" \
  --substitutions="_PROJECT_ID=${PROJECT_ID},_STATE_BUCKET=${STATE_BUCKET},_IAP_USER_EMAIL=${IAP_USER_EMAIL},_SAVE_PLAN=false" \
  --service-account="projects/${PROJECT_ID}/serviceAccounts/${CB_SA}"

# Main plan trigger — fires on push to main (a merged PR) when terraform/ files change.
# Same pipeline with _SAVE_PLAN=true: the plan is uploaded to gs://STATE_BUCKET/plans/BUILD_ID/.
# This is the only plan the apply trigger is meant to use, so what is deployed always comes from main.
gcloud builds triggers create github \
  --project=${PROJECT_ID} \
  --name="terraform-plan-main" \
  --repo-name="${REPO_NAME}" \
  --repo-owner="${REPO_OWNER}" \
  --branch-pattern="^main$" \
  --included-files="terraform/**" \
  --build-config="cloudbuild/terraform-plan.yaml" \
  --substitutions="_PROJECT_ID=${PROJECT_ID},_STATE_BUCKET=${STATE_BUCKET},_IAP_USER_EMAIL=${IAP_USER_EMAIL},_SAVE_PLAN=true" \
  --service-account="projects/${PROJECT_ID}/serviceAccounts/${CB_SA}"

# Apply trigger — triggered manually after reviewing the plan generated on main.
# Requires --require-approval so no one can run it without explicit approval.
# Override _PLAN_BUILD_ID with the BUILD_ID of the terraform-plan-main run you want to apply.
# A plan with destructive changes is rejected unless _ALLOW_DESTRUCTIVE=true is passed at run time.
gcloud beta builds triggers create manual \
  --project=${PROJECT_ID} \
  --name="terraform-apply" \
  --repo="https://github.com/${REPO_OWNER}/${REPO_NAME}" \
  --repo-type="GITHUB" \
  --branch="main" \
  --build-config="cloudbuild/terraform-apply.yaml" \
  --substitutions="_PROJECT_ID=${PROJECT_ID},_STATE_BUCKET=${STATE_BUCKET},_PLAN_BUILD_ID=REPLACE_WITH_PLAN_BUILD_ID,_ALLOW_DESTRUCTIVE=false" \
  --service-account="projects/${PROJECT_ID}/serviceAccounts/${CB_SA}" \
  --require-approval

echo "Triggers created successfully."
echo ""
echo "To apply the plan generated by terraform-plan-main, run:"
echo "  gcloud beta builds triggers run terraform-apply \\"
echo "    --project=${PROJECT_ID} \\"
echo "    --branch=main \\"
echo "    --substitutions=_PLAN_BUILD_ID=<BUILD_ID_FROM_PLAN>"
echo ""
echo "If the plan has destructive changes, add _ALLOW_DESTRUCTIVE=true to the substitutions."
