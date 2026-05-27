resource "cloudflare_pages_project" "frontend" {
  account_id        = var.cloudflare_account_id
  name              = "gs01-${local.project}-${local.env}"
  production_branch = "main"

  build_config {
    build_command   = "npm run build"
    destination_dir = "dist"
    root_dir        = "app/frontend"
  }

  deployment_configs {
    production {
      environment_variables = {
        VITE_API_URL = "https://api-${local.project}.${var.cloudflare_zone_name}"
      }
    }
  }
}
