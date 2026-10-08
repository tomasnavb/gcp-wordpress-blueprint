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
| [google_compute_health_check.http](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_health_check) | resource |
| [google_compute_instance_template.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_template) | resource |
| [google_compute_region_autoscaler.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_autoscaler) | resource |
| [google_compute_region_instance_group_manager.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_instance_group_manager) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_autoscaler_name"></a> [autoscaler\_name](#input\_autoscaler\_name) | Name for the regional autoscaler resource | `string` | n/a | yes |
| <a name="input_base_instance_name"></a> [base\_instance\_name](#input\_base\_instance\_name) | Base name used when the MIG creates individual VM instances | `string` | n/a | yes |
| <a name="input_check_interval_sec"></a> [check\_interval\_sec](#input\_check\_interval\_sec) | How often the health check probe is sent to each instance (seconds) | `number` | n/a | yes |
| <a name="input_cooldown_period"></a> [cooldown\_period](#input\_cooldown\_period) | Seconds the autoscaler waits after a scaling event before re-evaluating (allows new instances to warm up) | `number` | n/a | yes |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Boot disk size in GB for each instance | `number` | n/a | yes |
| <a name="input_disk_type"></a> [disk\_type](#input\_disk\_type) | Boot disk type (pd-standard, pd-ssd, pd-balanced) | `string` | n/a | yes |
| <a name="input_distribution_policy_target_shape"></a> [distribution\_policy\_target\_shape](#input\_distribution\_policy\_target\_shape) | Instance distribution strategy across zones (EVEN or ANY) | `string` | n/a | yes |
| <a name="input_distribution_policy_zones"></a> [distribution\_policy\_zones](#input\_distribution\_policy\_zones) | Zones within the region where the MIG distributes instances for HA | `list(string)` | n/a | yes |
| <a name="input_extra_metadata"></a> [extra\_metadata](#input\_extra\_metadata) | Additional instance metadata, read by the startup script through the metadata server. Cannot override startup-script or enable-oslogin | `map(string)` | n/a | yes |
| <a name="input_health_check_name"></a> [health\_check\_name](#input\_health\_check\_name) | Name for the global HTTP health check resource | `string` | n/a | yes |
| <a name="input_health_check_port"></a> [health\_check\_port](#input\_health\_check\_port) | TCP port the health check probe connects to | `number` | n/a | yes |
| <a name="input_healthy_threshold"></a> [healthy\_threshold](#input\_healthy\_threshold) | Number of consecutive successful probes before an instance is considered healthy | `number` | n/a | yes |
| <a name="input_initial_delay_sec"></a> [initial\_delay\_sec](#input\_initial\_delay\_sec) | Seconds to wait after an instance starts before the auto-healer begins checking its health | `number` | n/a | yes |
| <a name="input_lb_utilization_target"></a> [lb\_utilization\_target](#input\_lb\_utilization\_target) | Target load balancing utilization ratio (0.0–1.0) the autoscaler maintains | `number` | n/a | yes |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | Machine type for WordPress instances (e.g. e2-standard-2) | `string` | n/a | yes |
| <a name="input_max_replicas"></a> [max\_replicas](#input\_max\_replicas) | Maximum number of instances the autoscaler can scale up to | `number` | n/a | yes |
| <a name="input_max_scaled_in_replicas"></a> [max\_scaled\_in\_replicas](#input\_max\_scaled\_in\_replicas) | Maximum number of instances the autoscaler can remove in a single scale-in window | `number` | n/a | yes |
| <a name="input_max_surge_fixed"></a> [max\_surge\_fixed](#input\_max\_surge\_fixed) | Maximum number of additional instances that can be created above target size during a rolling update | `number` | n/a | yes |
| <a name="input_max_unavailable_fixed"></a> [max\_unavailable\_fixed](#input\_max\_unavailable\_fixed) | Maximum number of instances that can be unavailable during a rolling update | `number` | n/a | yes |
| <a name="input_mig_name"></a> [mig\_name](#input\_mig\_name) | Name for the regional managed instance group | `string` | n/a | yes |
| <a name="input_min_replicas"></a> [min\_replicas](#input\_min\_replicas) | Minimum number of instances the autoscaler maintains regardless of load | `number` | n/a | yes |
| <a name="input_most_disruptive_allowed_action"></a> [most\_disruptive\_allowed\_action](#input\_most\_disruptive\_allowed\_action) | Most disruptive action allowed per instance during a rolling update (REPLACE, RESTART, or REFRESH) | `string` | n/a | yes |
| <a name="input_network"></a> [network](#input\_network) | Self-link of the VPC network to attach instances to | `string` | n/a | yes |
| <a name="input_port"></a> [port](#input\_port) | Port number associated with the named port | `number` | n/a | yes |
| <a name="input_port_name"></a> [port\_name](#input\_port\_name) | Named port exposed by the MIG and referenced by the load balancer backend service | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | GCP region for the instance template and MIG (regional deployment for HA) | `string` | n/a | yes |
| <a name="input_request_path"></a> [request\_path](#input\_request\_path) | HTTP path the health check requests (e.g. /wp-login.php to verify WordPress is responding) | `string` | n/a | yes |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | Email of the service account attached to each instance | `string` | n/a | yes |
| <a name="input_source_image"></a> [source\_image](#input\_source\_image) | Full path to the golden image built by Packer (projects/<project>/global/images/family/<family>) | `string` | n/a | yes |
| <a name="input_startup_script"></a> [startup\_script](#input\_startup\_script) | Startup script content executed on each instance boot | `string` | n/a | yes |
| <a name="input_subnetwork"></a> [subnetwork](#input\_subnetwork) | Name or self-link of the subnetwork to attach instances to | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Network tags applied to instances (used for firewall rule targeting) | `list(string)` | n/a | yes |
| <a name="input_template_name_prefix"></a> [template\_name\_prefix](#input\_template\_name\_prefix) | Name prefix for the instance template (a timestamp suffix is auto-appended on each update) | `string` | n/a | yes |
| <a name="input_time_window_sec"></a> [time\_window\_sec](#input\_time\_window\_sec) | Time window in seconds over which the scale-in control limit is evaluated | `number` | n/a | yes |
| <a name="input_timeout_sec"></a> [timeout\_sec](#input\_timeout\_sec) | How long to wait for a health check response before marking it failed (seconds) | `number` | n/a | yes |
| <a name="input_unhealthy_threshold"></a> [unhealthy\_threshold](#input\_unhealthy\_threshold) | Number of consecutive failed probes before an instance is considered unhealthy and replaced | `number` | n/a | yes |
| <a name="input_update_policy_minimal_action"></a> [update\_policy\_minimal\_action](#input\_update\_policy\_minimal\_action) | Least disruptive action taken on each instance during a rolling update | `string` | n/a | yes |
| <a name="input_update_policy_type"></a> [update\_policy\_type](#input\_update\_policy\_type) | Rolling update strategy: PROACTIVE (applies immediately) or OPPORTUNISTIC (applies on instance recreation) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_instance_group"></a> [instance\_group](#output\_instance\_group) | n/a |
| <a name="output_self_link"></a> [self\_link](#output\_self\_link) | n/a |
