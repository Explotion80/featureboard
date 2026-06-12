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