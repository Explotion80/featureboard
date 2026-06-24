# Wymagania: minimalna wersja Terraforma i providera google (~> 7.0 = 7.x)
terraform {
  required_version = ">= 1.15"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Stan Terraforma trzymany w buckecie GCS — współdzielony i wersjonowany
  backend "gcs" {
    bucket = "featureboard-500408-tfstate"
    prefix = "terraform/state"
  }
}

# Domyślny projekt i region dla wszystkich zasobów poniżej
provider "google" {
  project = var.project_id
  region = var.region
}

# Bucket na plik stanu Terraforma; wersjonowanie, możliwość odzyskania stanu po uszkodzeniu
resource "google_storage_bucket" "tfstate" {
  name     = "featureboard-500408-tfstate"
  location = var.region

  versioning {
    enabled = true
  }

  # Uprawnienia tylko przez IAM (bez ACL per plik), zakaz upubliczniania bucketa
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}

# Rejestr obrazów Dockera, tu CI pushuje obraz aplikacji (tag = git SHA)
resource "google_artifact_registry_repository" "featureboard" {
  repository_id = "featureboard"
  location = var.region
  format        = "DOCKER"
  description   = "FeatureBoard container images"
}

# Konto serwisowe, którym CI pushuje do rejestru (bez klucza — dostęp przez impersonację WIF)
resource "google_service_account" "github_ci" {
  account_id   = "github-ci"
  display_name = "GitHub Actions CI"
}

# Pool tożsamości zewnętrznych — kontener na tożsamości spoza GCP, którym ufamy
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
}

# Provider OIDC w poolu: ufaj tokenom podpisanym przez GitHub Actions
resource "google_iam_workload_identity_pool_provider" "github" {
  # Odwołanie do poola wyżej — Terraform sam wie, że pool musi powstać pierwszy
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"

  # Przepisanie pól z tokena GitHuba na atrybuty GCP (używane w uprawnieniach IAM)
  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  # Bramka: odrzucaj tokeny z repozytoriów innych właścicieli niż Explotion80
  attribute_condition = "assertion.repository_owner=='${var.github_owner}'"

  # Adres wystawcy tokenów — stąd GCP pobiera klucze publiczne GitHuba do weryfikacji podpisów
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}


# CI może pushować obrazy do rejestru (tylko ta jedna para rola+członek)
resource "google_artifact_registry_repository_iam_member" "ci_writer" {
  repository = google_artifact_registry_repository.featureboard.repository_id
  location = var.region
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.github_ci.email}"
}

# Tożsamość federacyjna repo Explotion80/featureboard może impersonować konto github-ci
resource "google_service_account_iam_member" "wif_impersonation" {
  service_account_id = google_service_account.github_ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/${var.github_repo}"
}

# API wymagane przez sieć i GKE w Terraformie, żeby nowy projekt wstawał bez ręcznego "services enable"
resource "google_project_service" "compute" {
  service = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "container" {
  service = "container.googleapis.com"
  disable_on_destroy = false
}

# własna sieć VPC, auto create subnetworks=false, żadnych podsieci z automatu
resource "google_compute_network" "vpc" {
  name                    = "featureboard-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.compute]
}

# podsieć dla klastra. Zakres główny dla węzłów i dwa dodatkowe dla podów i serwisów
resource "google_compute_subnetwork" "gke" {
  name = "featureboard-gke"
  network = google_compute_network.vpc.id
  region = var.region
  ip_cidr_range = "10.0.0.0/24" # węzły: 256 adresów

 secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16" # pody: hojnie, bo brak adresów dla podów boli najbardziej
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/20"
  }
}

# klaster gke standard, strefowy (darmowy limit GCP, na prod regionalny)
resource "google_container_cluster" "primary" {
  name     = "featureboard"
  location = var.zone

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.gke.id

  # Domyślną pulę usuwamy — węzłami zarządza osobny zasób niżej (zmiany bez przebudowy klastra)
  remove_default_node_pool = true
  initial_node_count       = 1

  # VPC-native: pody i serwisy biorą adresy z nazwanych zakresów naszej podsieci
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # workload indentity: pody będą mogły dostawać tożsamość GCP bez kluczy (wymagane do Cloud SQL)
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  # Dodatek HTTP Load Balancing = kontroler Ingress (glbc). Bez niego Ingress nie dostaje adresu.
  addons_config {
    http_load_balancing {
      disabled = false
    }
  }
  # klaster do nauki, będzie regularnie niszczony, na prod domyślnie true
  deletion_protection = false

  depends_on = [google_project_service.container]
}

# pula węzłówL 2x e2-medium na spot
resource "google_container_node_pool" "default" {
  name = "default-pool"
  cluster = google_container_cluster.primary.id
  node_count = 2

  node_config {
    machine_type = "e2-medium"
    preemptible  = true

    # dostęp do API GCP kontrolowany przez IAM
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]

    # wymagane, żeby workload identity działało na tej puli

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

# api: łączenie z usługą google - cloud sql - z naszą siecią + zarządzanie Cloud SQL
resource "google_project_service" "servicenetworking" {
  service = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "sqladmin" {
  service = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

# pula adresów w naszym VPC zarezerwowana dla zarządanzych usług Google - Private Services Access, potrzebna do Cloud SQL
resource "google_compute_global_address" "psa_range" {
  name = "featureboard-psa"
  purpose = "VPC_PEERING"
  address_type = "INTERNAL"
  prefix_length = 16
  network = google_compute_network.vpc.id
}

# Peering naszego VPC z siecią usług Google - cloud sql z prywatny IP
resource "google_service_networking_connection" "psa" {
  network = google_compute_network.vpc.id
  service = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa_range.name]

  depends_on = [google_project_service.servicenetworking]
}


# instancja PostgreSQL z prywatnym IP
resource "google_sql_database_instance" "postgres" {
  name             = "featureboard-db"
  database_version = "POSTGRES_16"
  region           = var.region

  depends_on = [google_service_networking_connection.psa]

  settings {
    edition = "ENTERPRISE"
    tier              = "db-f1-micro" # najmniejszy; gdyby GCP odrzucił: gcloud sql tiers list
    availability_type = "ZONAL"       # jedna strefa (na prod: REGIONAL dla HA)
    disk_size         = 10

    ip_configuration {
      ipv4_enabled    = false                          # KLUCZOWE: brak publicznego IP
      private_network = google_compute_network.vpc.id  # baza w naszym VPC przez peering
    }

    backup_configuration {
      enabled = true
    }
  }
  
  deletion_protection = false
}

# Baza danych aplikacji wewnątrz instancji
resource "google_sql_database" "featureboard" {
  name     = "featureboard"
  instance = google_sql_database_instance.postgres.name
}

# Hasło generowane przez Terraform (nie wpisujemy go ręcznie nigdzie)
resource "random_password" "db" {
  length  = 32
  special = false # alfanumeryczne — bez znaków psujących connection string
}

# Użytkownik aplikacji
resource "google_sql_user" "app" {
  name     = "featureboard"
  instance = google_sql_database_instance.postgres.name
  password = random_password.db.result
}


# APIT Secret Manager
resource "google_project_service" "secretmanager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# skrytka na hasła do bazy
resource "google_secret_manager_secret" "db_password" {
  secret_id = "featureboard-db-password"

  replication {
    auto {}
  }

  depends_on = [ google_project_service.secretmanager ]
}

# zawartość skrytki - wygenerowane hasło
resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db.result
}

# konto serwisowe aplikacji - GKE
resource "google_service_account" "app" {
  account_id = "featureboard-app"
  display_name = "FeaTureBoard application"
}

# aplikacja może odczytać to konkretne hasło
resource "google_secret_manager_secret_iam_member" "app_reads_password" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app.email}"
}

# Workload Identity: pod z KSA "featureboard/featureboard" działa jako to konto GCP
resource "google_service_account_iam_member" "app_workload_identity" {
  service_account_id = google_service_account.app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[featureboard/featureboard]"

  depends_on = [google_container_cluster.primary]
}