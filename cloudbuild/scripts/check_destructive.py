import json
import os
import sys

# Resource types that are routinely replaced during normal updates and carry no data loss risk.
# Instance templates are immutable in GCP — any metadata change forces a replace.
# IAM bindings are replaced when a role or member changes — no data involved.
SAFE_TO_REPLACE = {
    "google_compute_instance_template",
    "google_cloudfunctions2_function_iam_member",
    "google_project_iam_member",
    "google_storage_bucket_iam_member",
    "google_secret_manager_secret_iam_member",
    "google_service_account_iam_member",
    "google_cloud_run_service_iam_member",
}

with open('/workspace/terraform/plan.json') as f:
    plan = json.load(f)

destructive_changes = []
for resource_change in plan.get('resource_changes', []):
    actions = resource_change.get('change', {}).get('actions', [])
    if 'delete' not in actions:
        continue

    resource_type = resource_change.get('type', '')
    is_replace = 'create' in actions
    label = 'replace' if is_replace else 'destroy'

    # Skip resources that are routinely replaced without data loss risk.
    if is_replace and resource_type in SAFE_TO_REPLACE:
        print(f"  [replace/safe] {resource_change['address']} — skipped ({resource_type})")
        continue

    destructive_changes.append((resource_change['address'], label))

if destructive_changes:
    print("Destructive changes detected:")
    for address, label in destructive_changes:
        print(f"  [{label}] {address}")

    allow = os.environ.get('ALLOW_DESTRUCTIVE_CHANGES', 'false').lower()
    if allow != 'true':
        print("\nDestructive changes are not allowed. Set ALLOW_DESTRUCTIVE_CHANGES=true to override.")
        sys.exit(1)
    else:
        print("\nDestructive changes allowed. Proceeding.")
else:
    print("No destructive changes detected.")
