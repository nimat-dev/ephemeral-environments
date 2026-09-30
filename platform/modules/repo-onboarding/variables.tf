variable "repository" {
  description = "GitHub repo that deploys previews, owner/name."
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$", var.repository))
    error_message = "repository must be owner/name."
  }
}

variable "app" {
  description = "Preview app slug (repo var PREVIEW_APP): namespaces preview-<app>-<branch> (F015). The CI identity may only write those."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,18}[a-z0-9])?$", var.app))
    error_message = "app must be a DNS label of at most 20 chars."
  }
}

variable "image_name" {
  description = "ACR repository prefix for this repo's images (APP_IMAGE_NAME; components live under it, DEC-046)."
  type        = string
}

variable "preview_domain" {
  description = "This project's preview domain (DEC-040); served by the cluster (a7 / clusters/<team>/config)."
  type        = string
}

variable "display_name" {
  description = "Entra application display name. Default gh-preview-<app>."
  type        = string
  default     = null
}

variable "federated_subjects" {
  description = <<-EOT
    GitHub OIDC subjects (name => subject) allowed to sign in as this repo's identity, e.g. the legacy
    repo:<owner>/<repo>:environment:preview and, when the repo issues immutable subjects, the
    repo:<owner>@<id>/<repo>@<id>:environment:preview form (DEC-030).
  EOT
  type        = map(string)
  validation {
    condition     = length(var.federated_subjects) > 0 && alltrue([for s in values(var.federated_subjects) : endswith(s, ":environment:preview")])
    error_message = "at least one subject, all scoped to the preview environment."
  }
}

variable "cluster" {
  description = "Team cluster the repo deploys to (team-cluster outputs)."
  type = object({
    id                  = string
    name                = string
    resource_group_name = string
    acr_id              = string
    acr_name            = string
    acr_login_server    = string
  })
}

variable "subscription_id" {
  type = string
}

variable "interceptor" {
  type = object({
    fqdn = string
    port = number
  })
  default = {
    fqdn = "keda-add-ons-http-interceptor-proxy.keda.svc.cluster.local"
    port = 8080
  }
}

variable "ingress_class" {
  type    = string
  default = "traefik"
}
