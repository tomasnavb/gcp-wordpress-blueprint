import json
import os
import sys

with open('/workspace/plan.json') as f:
    plan = json.load(f)

destructive_changes = []
for resource_change in plan.get('resource_changes', []):
    actions = resource_change.get('change', {}).get('actions', [])
    if 'delete' in actions:
        label = 'replace' if 'create' in actions else 'destroy'
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
