variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_zone_id" {
  type = string
}

variable "cloudflare_zone_name" {
  type        = string
  description = "Public DNS zone, for example example.com."
}

variable "cloudflare_account_id" {
  type = string
}

variable "lb_ip_aws" {
  type        = string
  description = "AWS EKS LoadBalancer external IP."
}

variable "lb_ip_azure" {
  type        = string
  description = "Azure AKS LoadBalancer external IP."
}
