resource "google_compute_network" "main" {
  name                    = "vpc-${local.project}-${local.env}"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "gke" {
  name          = "snet-gke-${local.project}-${local.env}"
  region        = local.region
  network       = google_compute_network.main.id
  ip_cidr_range = "10.0.0.0/20"

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.10.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.20.0.0/20"
  }

  private_ip_google_access = true
}
