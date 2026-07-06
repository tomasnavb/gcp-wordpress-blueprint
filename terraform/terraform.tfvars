# ==============================================================
# PROJECT
# Set project_id via environment variable to avoid committing it:
#   export TF_VAR_project_id="your-gcp-project-id"
# ==============================================================
project_region = "europe-west1"
project_zone   = "europe-west1-b"
iap_user_email = "tomasnavarro.dev@gmail.com"

# ==============================================================
# NETWORKING
# ==============================================================
vpc_prod_name             = "wordpress-prod-vpc"
subnet_prod_name          = "wordpress-prod-subnet"
subnet_prod_region        = "europe-west1"
subnet_prod_ip_cidr_range = "10.0.0.0/24"

vpc_mgmt_name             = "wordpress-mgmt-vpc"
subnet_mgmt_name          = "wordpress-mgmt-subnet"
subnet_mgmt_region        = "europe-west1"
subnet_mgmt_ip_cidr_range = "192.168.1.0/24"

# ==============================================================
# COMPUTE — MANAGEMENT VM
# ==============================================================
vm_mgmt_name         = "wordpress-mgmt-vm"
vm_mgmt_machine_type = "e2-medium"

# ==============================================================
# COMPUTE — MIG (Production)
# ==============================================================
instance_template_name_prefix    = "wordpress-prod-template-"
machine_type                     = "e2-standard-2"
instance_template_tags           = ["backend-service", "iap-ssh-access"]
mig_name                         = "wordpress-prod-mig"
base_instance_name               = "wordpress-prod"
distribution_policy_zones        = ["europe-west1-b", "europe-west1-c", "europe-west1-d"]
distribution_policy_target_shape = "EVEN"
port_name                        = "http"
port                             = 80
update_policy_type               = "PROACTIVE"
update_policy_minimal_action     = "REPLACE"
most_disruptive_allowed_action   = "REPLACE"
max_surge_fixed                  = 3
max_unavailable_fixed            = 0
initial_delay_sec                = 300

# ==============================================================
# COMPUTE — HEALTH CHECK
# ==============================================================
health_check_name   = "wordpress-prod-http-hc"
check_interval_sec  = 10
timeout_sec         = 5
healthy_threshold   = 2
unhealthy_threshold = 3
health_check_port   = 80
request_path        = "/health.php"

# ==============================================================
# COMPUTE — AUTOSCALER
# ==============================================================
autoscaler_name        = "wordpress-prod-autoscaler"
min_replicas           = 1
max_replicas           = 3
cooldown_period        = 60
lb_utilization_target  = 0.8
time_window_sec        = 300
max_scaled_in_replicas = 1

# ==============================================================
# DATABASE
# instance_tier reduced for portfolio cost (prod recommendation: db-custom-4-16384)
# ==============================================================
instance_name         = "wordpress-prod-db"
instance_region       = "europe-west1"
instance_tier         = "db-custom-2-4096"
instance_disk_size_gb = 20

# ==============================================================
# STORAGE
# Final bucket names are: <base_name>-<project_id>  (see locals.tf)
# ==============================================================
db_backup_bucket_base_name = "wordpress-db-backups"
scripts_bucket_base_name   = "wordpress-fn-scripts"

# ==============================================================
# CLOUD FUNCTION
# ==============================================================
function_name   = "wordpress-fn-db-backup-prod"
function_region = "europe-west1"

# ==============================================================
# CLOUD SCHEDULER
# ==============================================================
time_zone            = "Europe/Paris"
http_method          = "POST"
attempt_deadline     = "60s"
retry_count          = 3
max_retry_duration   = "300s"
min_backoff_duration = "10s"
max_backoff_duration = "60s"
max_doublings        = 2
