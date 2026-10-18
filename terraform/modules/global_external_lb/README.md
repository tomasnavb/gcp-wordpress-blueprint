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
| [google_compute_backend_service.mig](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_backend_service) | resource |
| [google_compute_firewall.allow_google_frontends](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_global_address.external_ip](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_global_forwarding_rule.http](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule) | resource |
| [google_compute_global_forwarding_rule.https](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule) | resource |
| [google_compute_health_check.backend_health_check](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_health_check) | resource |
| [google_compute_managed_ssl_certificate.https](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_managed_ssl_certificate) | resource |
| [google_compute_ssl_policy.https](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_ssl_policy) | resource |
| [google_compute_target_http_proxy.http](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_http_proxy) | resource |
| [google_compute_target_https_proxy.https](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_https_proxy) | resource |
| [google_compute_url_map.external_lb_url_map](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_url_map) | resource |
| [google_compute_url_map.http_redirect](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_url_map) | resource |
| [google_compute_global_address.reserved](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_global_address) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_backend_port"></a> [backend\_port](#input\_backend\_port) | TCP port behind the named port, opened in the firewall rule for traffic from the load balancer | `number` | n/a | yes |
| <a name="input_backend_port_name"></a> [backend\_port\_name](#input\_backend\_port\_name) | Named port of the instance group the backend service sends traffic to | `string` | n/a | yes |
| <a name="input_backend_service_protocol"></a> [backend\_service\_protocol](#input\_backend\_service\_protocol) | Protocol used between the load balancer and backend instances (HTTP or HTTPS) | `string` | n/a | yes |
| <a name="input_backend_target_tags"></a> [backend\_target\_tags](#input\_backend\_target\_tags) | Network tags of the backend instances the firewall rule applies to (must be present in the instance template tags) | `list(string)` | n/a | yes |
| <a name="input_balancing_mode"></a> [balancing\_mode](#input\_balancing\_mode) | Backend balancing mode: RATE (requests per second) or UTILIZATION (CPU) | `string` | n/a | yes |
| <a name="input_capacity_scaler"></a> [capacity\_scaler](#input\_capacity\_scaler) | Multiplier applied to the backend's capacity (1.0 = 100%) | `number` | n/a | yes |
| <a name="input_domain_names"></a> [domain\_names](#input\_domain\_names) | Domains included in the Google-managed SSL certificate | `list(string)` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment, last part of every resource name (dev or prod) | `string` | n/a | yes |
| <a name="input_health_check_request_path"></a> [health\_check\_request\_path](#input\_health\_check\_request\_path) | HTTP path the health check requests on the backend instances | `string` | n/a | yes |
| <a name="input_http_health_check_port"></a> [http\_health\_check\_port](#input\_http\_health\_check\_port) | TCP port the health check probes on the backend instances | `number` | n/a | yes |
| <a name="input_load_balancing_scheme"></a> [load\_balancing\_scheme](#input\_load\_balancing\_scheme) | Load balancing scheme applied to both forwarding rules and the backend service (EXTERNAL\_MANAGED) | `string` | n/a | yes |
| <a name="input_max_rate_per_instance"></a> [max\_rate\_per\_instance](#input\_max\_rate\_per\_instance) | Maximum requests per second per backend instance (only applicable if balancing\_mode is RATE) | `number` | n/a | yes |
| <a name="input_mig_instance_group"></a> [mig\_instance\_group](#input\_mig\_instance\_group) | Self-link of the regional MIG instance group to attach as the backend | `string` | n/a | yes |
| <a name="input_min_tls_version"></a> [min\_tls\_version](#input\_min\_tls\_version) | Minimum TLS version accepted from clients (TLS\_1\_0, TLS\_1\_1 or TLS\_1\_2) | `string` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix of every resource name. Names are <name\_prefix>-<component>-<environment>, e.g. myapp-lb-ip-prod. With use\_reserved\_ip, the IP is looked up by that name | `string` | n/a | yes |
| <a name="input_network_self_link"></a> [network\_self\_link](#input\_network\_self\_link) | Self-link of the VPC network of the backends, where the firewall rule is created | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID where the load balancer firewall rule is created | `string` | n/a | yes |
| <a name="input_ssl_policy_profile"></a> [ssl\_policy\_profile](#input\_ssl\_policy\_profile) | Cipher profile of the SSL policy (COMPATIBLE, MODERN or RESTRICTED) | `string` | n/a | yes |
| <a name="input_use_reserved_ip"></a> [use\_reserved\_ip](#input\_use\_reserved\_ip) | true: use a global address reserved outside Terraform, looked up by name, which survives terraform destroy. false: create the address here and destroy it with the load balancer | `bool` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_certificate_name"></a> [certificate\_name](#output\_certificate\_name) | Name of the Google-managed SSL certificate (changes with the domain list) |
| <a name="output_external_lb_ip"></a> [external\_lb\_ip](#output\_external\_lb\_ip) | External IP address of the load balancer (reserved beforehand or created by this module) |
