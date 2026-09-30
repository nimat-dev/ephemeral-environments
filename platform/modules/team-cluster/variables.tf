variable "resource_group_name" {
  description = "Existing resource group (never created or deleted by this module)."
  type        = string
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "cluster_name" {
  type = string
}

variable "dns_prefix" {
  description = "AKS API server DNS prefix (immutable once created)."
  type        = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.35"
}

variable "node_size" {
  description = "System node VM size (DEC-041: 1 node for a testing cluster)."
  type        = string
  default     = "Standard_D2as_v7"
}

variable "node_count" {
  type    = number
  default = 1
  validation {
    condition     = var.node_count >= 1 && var.node_count <= 10
    error_message = "node_count must be 1..10."
  }
}

variable "acr_name" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9]{5,50}$", var.acr_name))
    error_message = "acr_name must be 5-50 lowercase alphanumerics."
  }
}

variable "dns_zone" {
  description = "The team's base preview domain (Azure DNS zone)."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "admin_ssh_public_key" {
  description = "Node admin SSH public key (immutable: changing it replaces the cluster). null = none."
  type        = string
  default     = null
}

variable "flux" {
  description = <<-EOT
    GitOps for in-cluster add-ons (F019, DEC-039): AKS microsoft.flux extension + a flux configuration
    syncing `<path>/releases` then `<path>/config` from a public Git repo. null = no Flux.
  EOT
  type = object({
    repository_url = string
    branch         = string
    path           = string # e.g. ./clusters/nimat
  })
  default = null
  validation {
    condition     = var.flux == null || (startswith(try(var.flux.repository_url, ""), "https://") && startswith(try(var.flux.path, ""), "./"))
    error_message = "flux.repository_url must be https://..., flux.path must start with ./"
  }
}
