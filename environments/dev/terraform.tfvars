# environments/dev/terraform.tfvars
# Non-sensitive variable values for the dev environment.
# Secrets (vm_admin_ssh_public_key) are injected via CI environment variables
# or a secrets manager — never committed to source control.

app_name     = "myapp"
environment  = "dev"
location     = "eastus"
region_short = "eus"
cost_center  = "engineering"
owner        = "platform-team"

vnet_address_space = ["10.10.0.0/16"]
subnet_app_cidr    = "10.10.1.0/24"
subnet_data_cidr   = "10.10.2.0/24"

# Restrict to your VPN/office IP in practice
allowed_ssh_cidr = "0.0.0.0/0"

vm_size           = "Standard_B2s"
vm_admin_username = "azureadmin"
data_disk_size_gb = 32
