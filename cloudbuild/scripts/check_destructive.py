"""Check a Terraform plan (JSON) for destructive changes.

Environment variables:
  CHECK_MODE         "report"  — list destructive changes and exit 0 (plan pipelines).
                     "enforce" — fail unless the changes are allowed (apply pipeline). Default.
  ALLOW_DESTRUCTIVE  "true" lets enforce mode pass a plan with destructive changes.
                     It never overrides PROTECTED resources.
  PLAN_JSON          Path to the output of `terraform show -json tfplan`.
"""
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
    "google_cloud_run_v2_service_iam_member",
}

# Individual resources that are safe to replace although their type is not safe in general.
# The function source zip is named after its content hash, so any change to it uploads a new
# object and removes the old one. It is rebuilt from the repository on every plan: no data in it.
# Listed by address and not by type, because another bucket object could hold data.
SAFE_TO_REPLACE_ADDRESSES = {
    "google_storage_bucket_object.function_code",
}

# Resources that hold data. Destroying or replacing them is blocked in enforce mode
# even with ALLOW_DESTRUCTIVE=true. Removing an entry here requires a reviewed commit.
PROTECTED_TYPES = {
    "google_sql_database_instance",
    "google_sql_database",
}
PROTECTED_ADDRESSES = {
    "google_storage_bucket.cloudsql_backups",
}


def find_destructive_changes(plan):
    """Return (destructive, protected) lists of (address, label) from a plan."""
    destructive = []
    protected = []

    for resource_change in plan.get('resource_changes', []):
        actions = resource_change.get('change', {}).get('actions', [])
        if 'delete' not in actions:
            continue

        address = resource_change['address']
        resource_type = resource_change.get('type', '')
        is_replace = 'create' in actions
        label = 'replace' if is_replace else 'destroy'

        if resource_type in PROTECTED_TYPES or address in PROTECTED_ADDRESSES:
            protected.append((address, label))
            continue

        # Skip resources that are routinely replaced without data loss risk.
        if is_replace and (resource_type in SAFE_TO_REPLACE or address in SAFE_TO_REPLACE_ADDRESSES):
            print(f"  [replace/safe] {address} — skipped ({resource_type})")
            continue

        destructive.append((address, label))

    return destructive, protected


def main():
    mode = os.environ.get('CHECK_MODE', 'enforce').lower()
    allow = os.environ.get('ALLOW_DESTRUCTIVE', 'false').lower() == 'true'
    plan_path = os.environ.get('PLAN_JSON', '/workspace/terraform/plan.json')

    if mode not in ('report', 'enforce'):
        print(f"Invalid CHECK_MODE '{mode}'. Allowed values: report, enforce.")
        return 1

    with open(plan_path) as f:
        plan = json.load(f)

    destructive, protected = find_destructive_changes(plan)

    if not destructive and not protected:
        print("No destructive changes detected.")
        return 0

    if protected:
        print("Destructive changes on PROTECTED resources (data loss):")
        for address, label in protected:
            print(f"  [{label}] {address}")

    if destructive:
        print("Destructive changes detected:")
        for address, label in destructive:
            print(f"  [{label}] {address}")

    if mode == 'report':
        print("\nReport only. The apply pipeline will require ALLOW_DESTRUCTIVE=true for this plan.")
        if protected:
            print("Protected resources cannot be applied through the pipeline.")
        return 0

    if protected:
        print("\nProtected resources cannot be destroyed or replaced through the pipeline.")
        return 1

    if not allow:
        print("\nDestructive changes are not allowed. Set ALLOW_DESTRUCTIVE=true to override.")
        return 1

    print("\nDestructive changes allowed. Proceeding.")
    return 0


if __name__ == '__main__':
    sys.exit(main())
