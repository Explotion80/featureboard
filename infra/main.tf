terraform {
  required_version = ">= 1.15"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
  backend "gcs" {
    bucket = "featureboard-499107-tfstate"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = "featureboard-499107"
  region  = "europe-central2"
}

resource "google_storage_bucket" "tfstate" {
    name = "featureboard-499107-tfstate"
    location = "europe-central2"

    versioning {
        enabled = true
    }

    uniform_bucket_level_access = true
    public_access_prevention = "enforced"
}