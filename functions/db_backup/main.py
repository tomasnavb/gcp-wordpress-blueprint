'''Cloud Function to perform on-demand backups of a Cloud SQL instance. - 
Triggered by an HTTP request with a JSON body containing the backup type (snapshot, export, or both).
- Uses the Cloud SQL Admin API to create backups and exports, and waits for operations to complete before returning results.'''

import functions_framework
from googleapiclient.discovery import build
from google.cloud import storage
import logging
from datetime import datetime
import time
import json
import os

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
# Ver de reemplazar por os.environ (Provoca error si no encuentra la ENV)
PROJECT_ID = os.getenv("GCP_PROJECT_ID")
INSTANCE_NAME = os.getenv("CLOUD_SQL_INSTANCE_NAME")
BACKUP_BUCKET = os.getenv("BACKUP_BUCKET_NAME")


@functions_framework.http
def run_backup(request):
    """Execute a backup based on the specified type in the request. - Triggered by an HTTP request with a JSON body containing the backup type."""
    request_json = request.get_json(silent=True) or {}
    backup_type = request_json.get("type", "both")

    # Only allow specific backup types for security and consistency
    allowed_types = {"snapshot", "export", "both"}
    if backup_type not in allowed_types:
        return json.dumps({
            "status": "failed",
            "message": f"Invalid backup type. Allowed values: {allowed_types}"
        }), 400

    results = {}

    try:
        if backup_type in ("snapshot", "both"):
            results["snapshot"] = create__backup_snapshot()

        if backup_type in ("export", "both"):
            results["export"] = "Execute Export"

        logger.info(f"Backup executed succesfully {json.dumps(results)}")
        return json.dumps({"status": "success", "result": results}), 200

    except Exception as e:
        logger.error(f"Backup failed: {e}")
        return json.dumps({"status": "failed", "message": str(e)}), 500


def create__backup_snapshot():
    """Create on-demand backup snapshot of the Cloud SQL instance using the Cloud SQL Admin API."""
    service = build("sqladmin", "v1beta4", cache_discovery=False)

    body = {
        "kind": "sql#backupRun",
        "description": f"Automated backup - {datetime.utcnow().isoformat()}",
    }

    request = service.backupRuns().insert(
        project=PROJECT_ID,
        instance=INSTANCE_NAME,
        body=body,
    )

    response = request.execute()
    operation_id = response.get("name")

    # Wait for the backup operation to complete
    wait_for_operation(service, operation_id)

    logger.info(f"Backup snapshot created: {operation_id}")
    return {"operation_id": operation_id, "status": "completed"}


def create_export():
    """Create an export of the database to a Cloud Storage bucket using the Cloud SQL Admin API."""
    service = build("sqladmin", "v1beta4", cache_discovery=False)

    body = {
        "exportContext": {
            "kind": "sql#exportContext",
            "fileType": "SQL",
            "uri": f"gs://{BACKUP_BUCKET}/exports/{INSTANCE_NAME}_{datetime.utcnow().isoformat()}.sql.gz",
            "databases": [],
            "sqlExportOptions": {
                "schemaOnly": False,
            },
            "offload": True,
        }
    }

    request = service.instances().export(
        project=PROJECT_ID,
        instance=INSTANCE_NAME,
        body=body,
    )

    response = request.execute()
    operation_id = response.get("name")

    # Wait for the export operation to complete
    wait_for_operation(service, operation_id)

    logger.info(f"Export created: {operation_id}")
    return {"operation_id": operation_id, "status": "completed"}


def wait_for_operation(service, operation_id, timeout=600):
    """Wait for a Cloud SQL operation to complete, with a timeout."""
    start_time = time.time()

    while time.time() - start_time < timeout:
        result = (
            service.operations()
            .get(
                project=PROJECT_ID,
                operation=operation_id,
            )
            .execute()
        )

        status = result.get("status")
        if status == "DONE":
            if "error" in result:
                raise Exception(f"Operation failed: {result['error']}")
            return result

        time.sleep(10)

    raise Exception(f"Operation {operation_id} timed out after {timeout}s")
