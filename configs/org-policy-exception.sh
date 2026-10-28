#!/bin/bash
set -e

# ==============================================================
# Domain restricted sharing: exception for the load balancer's service agent.
#
# Only needed when the project is in an organization that enforces domain restricted sharing
# (iam.allowedPolicyMemberDomains), which organizations created since May 2024 do by default.
# Without an organization there is nothing to inherit, and this script does nothing.
#
# Why: the load balancer reads the private uploads bucket with a Google-managed service agent,
# service-<project_number>@https-lb.iam.gserviceaccount.com (Private Bucket Access), and Terraform
# grants it read access on the bucket. That service agent does not belong to your organization, so
# domain restricted sharing rejects the binding at apply time:
#   "One or more users named in the policy do not belong to a permitted customer"
#
# The legacy constraint accepts no exceptions for single principals. So, in this project only:
#   1. the managed constraint iam.managed.allowedPolicyMembers is enforced: your organization, plus
#      that service agent as the one exception;
#   2. then the legacy constraint is reset to its default, allow all. The managed one replaces it,
#      and it goes first, so the project is never left without the restriction.
#
# Run once from Cloud Shell, after configs/setup.sh and before the first terraform apply:
#   bash configs/org-policy-exception.sh
#
# Needs roles/orgpolicy.policyAdmin on the organization (owning the organization is not enough).
# Changes can take up to 15 minutes to apply.
#
# Export PROJECT_ID before running. It asks to type the project ID before changing anything.
# ==============================================================

export PROJECT_ID="${PROJECT_ID:-your-gcp-project-id}"

if [[ "${PROJECT_ID}" == your-* ]]; then
  echo "ERROR: PROJECT_ID is not set. Export it before running this script." >&2
  exit 1
fi

# get-ancestors lists the project, its folders and its organization; keep the organization ID.
ORG_ID=$(gcloud projects get-ancestors "${PROJECT_ID}" --format="csv[no-heading](id,type)" | awk -F, '$2=="organization" {print $1}')
if [[ -z "${ORG_ID}" ]]; then
  echo "${PROJECT_ID} is not in an organization: there is no domain restricted sharing to adjust."
  exit 0
fi

# gcloud org-policies needs the Organization Policy API on the project.
gcloud services enable orgpolicy.googleapis.com --project="${PROJECT_ID}"

if ! gcloud org-policies describe iam.allowedPolicyMemberDomains --effective --project="${PROJECT_ID}" \
    --format=yaml 2>/dev/null | grep -q "allowedValues"; then
  echo "Domain restricted sharing (iam.allowedPolicyMemberDomains) is not enforced on ${PROJECT_ID}: nothing to adjust."
  exit 0
fi

PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")
LB_SERVICE_AGENT="service-${PROJECT_NUMBER}@https-lb.iam.gserviceaccount.com"

echo ""
echo "Domain restricted sharing is enforced on ${PROJECT_ID} (organization ${ORG_ID})."
echo "This enforces iam.managed.allowedPolicyMembers on the project, allowing the organization and"
echo "the load balancer's service agent, and then resets iam.allowedPolicyMemberDomains on the project."
read -r -p "Type the project ID (${PROJECT_ID}) to continue: " REPLY
if [[ "${REPLY}" != "${PROJECT_ID}" ]]; then
  echo "Confirmation does not match. Nothing was changed." >&2
  exit 1
fi

# The policy file holds the project number, so it is generated here and never written in the repository.
POLICY_FILE=$(mktemp)
trap 'rm -f "${POLICY_FILE}"' EXIT
cat > "${POLICY_FILE}" << EOF
name: projects/${PROJECT_ID}/policies/iam.managed.allowedPolicyMembers
spec:
  rules:
    - enforce: true
      parameters:
        allowedPrincipalSets:
          - "//cloudresourcemanager.googleapis.com/organizations/${ORG_ID}"
        allowedMemberSubjects:
          - "serviceAccount:${LB_SERVICE_AGENT}"
EOF

# 1. Managed constraint first, so the restriction is never off.
gcloud org-policies set-policy "${POLICY_FILE}" --update-mask=spec

# 2. Then the legacy constraint back to its default in this project only.
gcloud org-policies reset iam.allowedPolicyMemberDomains --project="${PROJECT_ID}"

echo ""
echo "Effective policies on ${PROJECT_ID}:"
gcloud org-policies describe iam.managed.allowedPolicyMembers --effective --project="${PROJECT_ID}"
gcloud org-policies describe iam.allowedPolicyMemberDomains --effective --project="${PROJECT_ID}"
echo ""
echo "Done. The legacy constraint must show allowAll: true. Changes can take up to 15 minutes to apply."
