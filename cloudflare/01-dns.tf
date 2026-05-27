resource "cloudflare_record" "api_aws" {
  zone_id = var.cloudflare_zone_id
  name    = "api-${local.project}"
  type    = "A"
  value   = var.lb_ip_aws
  proxied = true
  ttl     = 1
}

resource "cloudflare_record" "api_azure" {
  zone_id = var.cloudflare_zone_id
  name    = "api-${local.project}"
  type    = "A"
  value   = var.lb_ip_azure
  proxied = true
  ttl     = 1
}

resource "cloudflare_record" "frontend" {
  zone_id = var.cloudflare_zone_id
  name    = "multicloud"
  type    = "CNAME"
  value   = cloudflare_pages_project.frontend.subdomain
  proxied = true
  ttl     = 1
}
