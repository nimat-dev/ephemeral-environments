# Team "nimat" preview platform (DEC-036: one module instance per team). Values mirror the live
# resources that bootstrap/provision.sh + a3 created; imports.tf adopted them without recreate.
module "team_cluster" {
  source = "../../modules/team-cluster"

  resource_group_name = "nimatresourceg"
  location            = "eastus"
  cluster_name        = "aks-preview"
  dns_prefix          = "aks-previe-nimatresourceg-1325f7"
  kubernetes_version  = "1.35"
  node_size           = "Standard_D2as_v7"
  node_count          = 1
  acr_name            = "nimatpreviewacr"
  dns_zone            = "preview.nimat.dev"
  # Public key az generated at create time (bash provision); kept so import is not a replacement.
  flux = {
    repository_url = "https://github.com/nimat-dev/ephemeral-environments"
    branch         = "main"
    path           = "./clusters/nimat"
  }
  admin_ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDtwT2bIEaS8+oKxNCWSQbilwNImRs1m6IgNayIJZ9bnfvIici6grPu9NAT6KT7kKzo5mBa4c0zF7nxX2I+57PAriexj29evxCbhxmPAqkBN9JpLaTsf2bWDUSig5A6VYBAZdcwqzajYUYzIO+4VQNEnc+0dVvQFEYq3c/eAwHUOFrM5/sA1hfUwRRyTvWsivHskuRoMRHdsyNgI5vX95h+Rlqu0e4PZC612SDwcY6MpC+D1M8/YtbE+aeFP27wMftB2qxbaTZWfzVpOaZZ8du/+JJoyuoj4h5I+wRggrDHeuYEweEOqjz5EML5RtkaXwp+c/IymRZC0d4AecsOlAB9"
}

output "cluster_name" {
  value = module.team_cluster.cluster_name
}

output "oidc_issuer_url" {
  value = module.team_cluster.oidc_issuer_url
}

output "acr_login_server" {
  value = module.team_cluster.acr_login_server
}

output "dns_zone_name_servers" {
  value = module.team_cluster.dns_zone_name_servers
}

output "cert_manager_client_id" {
  value = module.team_cluster.cert_manager_client_id
}
