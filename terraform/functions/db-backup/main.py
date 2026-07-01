"""
Cloud Function to perform on-demand backups of a Cloud SQL instance.
Triggered by an HTTP request with a JSON body containing the backup type
(snapshot, export, or both). Uses the Cloud SQL Admin API to create backups
and exports, and waits for operations to complete before returning results.
"""

import functions_framework
from googleapiclient.discovery import build
import logging
from datetime import datetime
import time
import json
import os

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

PROJECT_ID = os.getenv("GCP_PROJECT_ID")
INSTANCE_NAME = os.getenv("CLOUD_SQL_INSTANCE_NAME")
BACKUP_BUCKET = os.getenv("BACKUP_BUCKET_NAME")


@functions_framework.http
def run_backup(request):
    """Execute a backup based on the type specified in the request body."""
    request_json = request.get_json(silent=True) or {}
    backup_type = request_json.get("type", "both")

    allowed_types = {"snapshot", "export", "both"}
    if backup_type not in allowed_types:
        return json.dumps({
            "status": "failed",
            "message": f"Invalid backup type. Allowed values: {allowed_types}"
        }), 400

    results = {}

    try:
        if backup_type in ("snapshot", "both"):
            results["snapshot"] = create_backup_snapshot()

        if backup_type in ("export", "both"):
            results["export"] = create_export()

        logger.info(f"Backup executed successfully: {json.dumps(results)}")
        return json.dumps({"status": "success", "result": results}), 200

    except Exception as e:
        logger.error(f"Backup failed: {e}")
        return json.dumps({"status": "failed", "message": str(e)}), 500


def create_backup_snapshot():
    """Create an on-demand backup snapshot via the Cloud SQL Admin API."""
    service = build("sqladmin", "v1beta4", cache_discovery=False)

    body = {
        "kind": "sql#backupRun",
        "description": f"Automated snapshot - {datetime.utcnow().isoformat()}",
    }

    response = service.backupRuns().insert(
        project=PROJECT_ID,
        instance=INSTANCE_NAME,
        body=body,
    ).execute()

    operation_id = response.get("name")
    wait_for_operation(service, operation_id)

    logger.info(f"Backup snapshot completed: {operation_id}")
    return {"operation_id": operation_id, "status": "completed"}


def create_export():
    """Export the database to a Cloud Storage bucket via the Cloud SQL Admin API."""
    service = build("sqladmin", "v1beta4", cache_discovery=False)

    timestamp = datetime.utcnow().strftime("%Y%m%d-%H%M%S")
    export_uri = f"gs://{BACKUP_BUCKET}/exports/{INSTANCE_NAME}_{timestamp}.sql.gz"

    body = {
        "exportContext": {
            "kind": "sql#exportContext",
            "fileType": "SQL",
            "uri": export_uri,
            "databases": [],
            "sqlExportOptions": {
                "schemaOnly": False,
            },
            "offload": True,
        }
    }

    response = service.instances().export(
        project=PROJECT_ID,
        instance=INSTANCE_NAME,
        body=body,
    ).execute()

    operation_id = response.get("name")
    wait_for_operation(service, operation_id)

    logger.info(f"Export completed: {operation_id} → {export_uri}")
    return {"operation_id": operation_id, "status": "completed", "uri": export_uri}


def wait_for_operation(service, operation_id, timeout=600):
    """Poll until a Cloud SQL operation reaches DONE status or timeout is exceeded."""
    start_time = time.time()

    while time.time() - start_time < timeout:
        result = service.operations().get(
            project=PROJECT_ID,
            operation=operation_id,
        ).execute()

        if result.get("status") == "DONE":
            if "error" in result:
                raise Exception(f"Operation failed: {result['error']}")
            return result

        time.sleep(10)

    raise Exception(f"Operation {operation_id} timed out after {timeout}s")
