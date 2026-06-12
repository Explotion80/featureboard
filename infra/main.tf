# Wymagania: minimalna wersja Terraforma i providera google (~> 7.0 = 7.x)
terraform {
  required_version = ">= 1.15"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }

  # Stan Terraforma trzymany w buckecie GCS — współdzielony i wersjonowany
  backend "gcs" {
    bucket = "featureboard-499107-tfstate"
    prefix = "terraform/state"
  }
}

# Domyślny projekt i region dla wszystkich zasobów poniżej
provider "google" {
  project = "featureboard-499107"
  region  = "europe-central2"
}

# Bucket na plik stanu Terraforma; wersjonowanie, możliwość odzyskania stanu po uszkodzeniu
resource "google_storage_bucket" "tfstate" {
  name     = "featureboard-499107-tfstate"
  location = "europe-central2"

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
  location      = "europe-central2"
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
  attribute_condition = "assertion.repository_owner=='Explotion80'"

  # Adres wystawcy tokenów — stąd GCP pobiera klucze publiczne GitHuba do weryfikacji podpisów
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}


# CI może pushować obrazy do rejestru (tylko ta jedna para rola+członek)
resource "google_artifact_registry_repository_iam_member" "ci_writer" {
  repository = google_artifact_registry_repository.featureboard.repository_id
  location   = "europe-central2"
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.github_ci.email}"
}

# Tożsamość federacyjna repo Explotion80/featureboard może impersonować konto github-ci
resource "google_service_account_iam_member" "wif_impersonation" {
  service_account_id = google_service_account.github_ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/Explotion80/featureboard"
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
  region = "europe-central2"
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