import functions_framework # type: ignore
from googleapiclient.discovery import build # pyright: ignore[reportMissingImports]
from googleapiclient.errors import HttpError # type: ignore
import logging
from datetime import datetime
import json
import os

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

PROJECT_ID = os.getenv("GCP_PROJECT_ID")
INSTANCE_NAME = os.getenv("CLOUD_SQL_INSTANCE_NAME")
BACKUP_BUCKET = os.getenv("BACKUP_BUCKET_NAME")


@functions_framework.http
def run_backup(request):
    request_json = request.get_json(silent=True) or {}
    backup_type = request_json.get("type", "export")

    # Only exports: point-in-time recovery comes from the instance's automated backups and binary logs.
    allowed_types = {"export"}
    if backup_type not in allowed_types:
        return json.dumps({
            "status": "failed",
            "message": f"Invalid backup type. Allowed values: {allowed_types}"
        }), 400

    results = {}

    try:
        results["export"] = create_export()

        logger.info(f"Backup started: {json.dumps(results)}")
        return json.dumps({"status": "success", "result": results}), 200

    except HttpError as e:
        if e.resp.status == 409:
            logger.info("Backup already in progress, skipping.")
            return json.dumps({"status": "skipped", "message": "Backup already in progress"}), 200
        logger.error(f"Backup failed: {e}")
        return json.dumps({"status": "failed", "message": str(e)}), 500

    except Exception as e:
        logger.error(f"Backup failed: {e}")
        return json.dumps({"status": "failed", "message": str(e)}), 500


def create_export():
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
    logger.info(f"Export started: {operation_id} → {export_uri}")
    return {"operation_id": operation_id, "status": "started", "uri": export_uri}
