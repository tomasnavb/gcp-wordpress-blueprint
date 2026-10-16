## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_cloud_scheduler_job.trigger_backup](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_scheduler_job) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_attempt_deadline"></a> [attempt\_deadline](#input\_attempt\_deadline) | Time limit for a single HTTP attempt before it is considered failed (e.g. 60s) | `string` | n/a | yes |
| <a name="input_backup_fn_uri"></a> [backup\_fn\_uri](#input\_backup\_fn\_uri) | HTTPS trigger URL of the Cloud Function to invoke | `string` | n/a | yes |
| <a name="input_description"></a> [description](#input\_description) | Human-readable description for the Cloud Scheduler job | `string` | n/a | yes |
| <a name="input_fn_backup_type"></a> [fn\_backup\_type](#input\_fn\_backup\_type) | Backup type sent in the request body to the function: 'export' (SQL export to Cloud Storage) | `string` | n/a | yes |
| <a name="input_http_method"></a> [http\_method](#input\_http\_method) | HTTP method used when invoking the Cloud Function (POST) | `string` | n/a | yes |
| <a name="input_invoker_service_account_email"></a> [invoker\_service\_account\_email](#input\_invoker\_service\_account\_email) | Email of the service account used in the OIDC token to authenticate the HTTP call to the Cloud Function | `string` | n/a | yes |
| <a name="input_max_backoff_duration"></a> [max\_backoff\_duration](#input\_max\_backoff\_duration) | Maximum wait time between retry attempts (e.g. 60s) | `string` | n/a | yes |
| <a name="input_max_doublings"></a> [max\_doublings](#input\_max\_doublings) | Maximum number of times the backoff interval is doubled before hitting max\_backoff\_duration | `number` | n/a | yes |
| <a name="input_max_retry_duration"></a> [max\_retry\_duration](#input\_max\_retry\_duration) | Total time the scheduler will keep retrying a failed job (e.g. 300s) | `string` | n/a | yes |
| <a name="input_min_backoff_duration"></a> [min\_backoff\_duration](#input\_min\_backoff\_duration) | Minimum wait time between retry attempts (e.g. 10s) | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the Cloud Scheduler job | `string` | n/a | yes |
| <a name="input_retry_count"></a> [retry\_count](#input\_retry\_count) | Maximum number of retry attempts if the function returns an error | `number` | n/a | yes |
| <a name="input_schedule"></a> [schedule](#input\_schedule) | Cron expression defining when the job fires (e.g. '0 0 * * *' for daily at midnight) | `string` | n/a | yes |
| <a name="input_time_zone"></a> [time\_zone](#input\_time\_zone) | Time zone used to interpret the cron schedule expression (e.g. Europe/Paris) | `string` | n/a | yes |

## Outputs

No outputs.
