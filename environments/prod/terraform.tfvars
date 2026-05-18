# environments/prod/terraform.tfvars

app_name     = "myapp"
environment  = "prod"
location     = "westus2"
region_short = "wus2"
cost_center  = "engineering"
owner        = "platform-team"

vnet_address_space = ["10.20.0.0/16"]
subnet_app_cidr    = "10.20.1.0/24"
subnet_data_cidr   = "10.20.2.0/24"

enable_ddos_protection = false

vm_size           = "Standard_D2s_v3"
vm_admin_username = "azureadmin"
data_disk_size_gb = 128
