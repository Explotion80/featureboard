# Wartości powtarzające się w całej infrastrukturze — jedno miejsce do zmiany.

variable "project_id" {
  description = "ID projektu GCP"
  type        = string
  default     = "featureboard-499107"
}

variable "region" {
  description = "Region GCP dla zasobów regionalnych"
  type        = string
  default     = "europe-central2"
}

variable "zone" {
  description = "Strefa GCP dla zasobów strefowych (np. klaster GKE)"
  type        = string
  default     = "europe-central2-a"
}

variable "github_owner" {
  description = "Właściciel repozytorium GitHub"
  type        = string
  default     = "Explotion80"
}

variable "github_repo" {
  description = "Nazwa repozytorium GitHub"
  type        = string
  default     = "featureboard"
}