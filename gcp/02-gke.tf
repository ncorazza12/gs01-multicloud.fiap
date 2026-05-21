data "google_client_config" "default" {}

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google"
  version = "~> 44.0"

  project_id = local.project_id
  name       = "gke-${local.project}-${local.env}"
  region     = local.region

  network           = google_compute_network.main.name
  subnetwork        = google_compute_subnetwork.gke.name
  ip_range_pods     = "pods"
  ip_range_services = "services"

  kubernetes_version = "1.33"
  release_channel    = "REGULAR"

  create_service_account = false
  service_account        = "default"

  http_load_balancing        = true
  horizontal_pod_autoscaling = true
  network_policy             = false
  dns_cache                  = false

  deletion_protection = false

  node_pools = [
    {
      name         = "default"
      machine_type = "e2-small"
      min_count    = 1
      max_count    = 2
      disk_size_gb = 50
      disk_type    = "pd-standard"
      image_type   = "COS_CONTAINERD"
      auto_repair  = true
      auto_upgrade = true
    },
  ]

  node_pools_oauth_scopes = {
    all = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  node_pools_labels   = { all = {} }
  node_pools_metadata = { all = {} }
  node_pools_taints   = { all = [] }
  node_pools_tags     = { all = [] }
}

output "configure_kubectl" {
  value = "gcloud container clusters get-credentials ${module.gke.name} --region ${local.region} --project ${local.project_id}"
}
