# Module: `vnet`

> **Reusable Azure Virtual Network module** — provisions a VNET, subnets, optional NSGs with rules, optional DDoS Protection, and an optional Network Watcher.

---

## Features

| Feature | Default |
|---|---|
| Virtual Network | ✅ always |
| Multiple subnets (via `for_each`) | ✅ always |
| Per-subnet NSG with custom rules | optional |
| Service delegation per subnet | optional |
| Azure DDoS Protection Standard | optional (costs extra) |
| Network Watcher | optional |
| Mandatory tagging (`environment`, `region`, `managed_by`) | ✅ always |

---

## Usage

```hcl
module "vnet" {
  source = "../../modules/vnet"

  vnet_name           = "vnet-myapp-dev-eastus"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.main.name
  environment         = "dev"
  address_space       = ["10.10.0.0/16"]

  subnets = [
    {
      name             = "snet-app"
      address_prefixes = ["10.10.1.0/24"]
      create_nsg       = true
      nsg_rules = [
        {
          name                   = "allow-https-inbound"
          priority               = 100
          direction              = "Inbound"
          access                 = "Allow"
          protocol               = "Tcp"
          destination_port_range = "443"
        },
        {
          name                   = "deny-all-inbound"
          priority               = 4096
          direction              = "Inbound"
          access                 = "Deny"
          protocol               = "*"
          destination_port_range = "*"
        }
      ]
    },
    {
      name             = "snet-data"
      address_prefixes = ["10.10.2.0/24"]
      create_nsg       = true
    }
  ]

  tags = {
    project    = "myapp"
    cost_center = "eng-platform"
  }
}
```

---

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.5 |
| azurerm | ~> 3.0 |

---

## Inputs

| Name | Type | Default | Required | Description |
|---|---|---|---|---|
| `vnet_name` | `string` | — | yes | Name of the Virtual Network |
| `location` | `string` | — | yes | Azure region (e.g. `eastus`) |
| `resource_group_name` | `string` | — | yes | Resource Group name |
| `environment` | `string` | — | yes | One of: `dev`, `staging`, `prod` |
| `address_space` | `list(string)` | — | yes | CIDR blocks for the VNET |
| `subnets` | `list(object)` | — | yes | Subnet definitions (see below) |
| `dns_servers` | `list(string)` | `[]` | no | Custom DNS IPs (empty = Azure DNS) |
| `tags` | `map(string)` | `{}` | no | Additional tags merged with module defaults |
| `enable_ddos_protection` | `bool` | `false` | no | Create DDoS Protection Standard plan |
| `create_network_watcher` | `bool` | `false` | no | Create a Network Watcher in this region |

### Subnet object

```hcl
{
  name             = string           # required
  address_prefixes = list(string)     # required
  create_nsg       = optional(bool)   # default: false
  nsg_rules        = optional(list(object({
    name                       = string
    priority                   = number
    direction                  = string   # "Inbound" | "Outbound"
    access                     = string   # "Allow" | "Deny"
    protocol                   = string   # "Tcp" | "Udp" | "*"
    source_port_range          = optional(string)
    destination_port_range     = optional(string)
    destination_port_ranges    = optional(list(string))
    source_address_prefix      = optional(string)
    destination_address_prefix = optional(string)
  })))
  delegation = optional(object({
    name                    = string
    service_delegation_name = string
    actions                 = optional(list(string))
  }))
}
```

---

## Outputs

| Name | Description |
|---|---|
| `vnet_id` | Resource ID of the VNET — used by downstream modules for NIC placement, peering |
| `vnet_name` | VNET name |
| `vnet_address_space` | VNET address space list |
| `subnet_ids` | `map(string)` — subnet name → subnet ID; use to place VMs, private endpoints |
| `subnet_address_prefixes` | `map(list(string))` — subnet name → CIDRs; avoids repeating values in NSG rules |
| `nsg_ids` | `map(string)` — subnet name → NSG ID; attach diagnostics or extra rules externally |
| `network_watcher_id` | Network Watcher ID (null if not created) |

---

## Design Decisions

### Why Resource Groups per environment instead of Subscriptions?

| Approach | Pros | Cons |
|---|---|---|
| **Resource Groups** (used here) | Simple, fast, no billing overhead, RBAC at RG level | Blast radius within subscription, quota sharing |
| **Subscriptions** | Strongest isolation, separate quotas & billing, policy boundary | More overhead, inter-sub peering needed, slower to provision |

For a small-to-medium team, Resource Groups with strict RBAC and Azure Policy are the pragmatic choice. The module is structured so migrating to a subscription-per-environment model requires only changing the provider alias — no module changes.

### Mandatory tags
The module always injects `environment`, `region`, and `managed_by=terraform` tags. This ensures cost attribution and policy compliance regardless of what callers supply.

### NSG per subnet vs. shared NSG
Each subnet gets its own NSG. This avoids rule sprawl and the hard-to-audit "one NSG for everything" anti-pattern. NSGs are only created when `create_nsg = true`, keeping the module lightweight for simple use-cases.

---

## Documentation Generation (automated)

This README is the source of truth, but `terraform-docs` can regenerate the Inputs/Outputs tables automatically:

```bash
# Install
brew install terraform-docs   # macOS
# or: go install github.com/terraform-docs/terraform-docs@latest

# Generate/update README
terraform-docs markdown table --output-file README.md --output-mode inject .
```

Add the following markers to this file to enable injection mode:

```
<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
```

The CI pipeline runs `terraform-docs` and commits updates via the `docs` job.

---

## Testing

Tests live in `tests/` using the [Terraform test framework](https://developer.hashicorp.com/terraform/language/tests) (native, no Go required).

```bash
# Run all tests (requires Azure credentials)
cd modules/vnet
terraform test
```

See [`tests/vnet_basic.tftest.hcl`](../../tests/vnet_basic.tftest.hcl) for examples.
