## FeatureBoard

Projekt do portfolio DevOps: prosta aplikacja FastAPI + PostgreSQL, wokół której
budowane są konkretne narzędzia: konteneryzacja, CI/CD, IaC, GitOps i observability. 
Głównym celem projektu nie jest sama aplikacja, tylko wszystko wokół niej.

## Stack
**Aplikacja** FastApi + PostgreSQL (psycopg, pydantic-settings)
**Konteneryzacja** Docker (multi-stage, non-root), docker-compose
**CI** GitHub Actions - ruff, pytest (z Postgresem jako service container),
build obrazu (tag = git SHA), skan podatności Trivy
**W planach** Terraform + GKE, Helm/Kustomize, Argo CD + Argo Rollouts, Prometheus/Grafana/Loki

## Jak uruchomić lokalnie

Wymagania: Docker desktop

```bash
docker compose up -d --build
```

Aplikacja: http://127.0.0.1:8000 (Swagger UI: http://127.0.0.1:8000/docs)

## Endpointy

| Endpoint | Opis |
|---|---|
| `GET /`       | środowisko i wersja aplikacji (z env) |
| `GET /health` | liveness — czy proces żyje (nie sprawdza bazy) |
| `GET /readyz` | readiness — czy baza odpowiada (503, gdy nie) |
| `POST /notes` | dodaje notatkę |
| `GET /notes`  | listuje notatki |

## Testy

```bash
pip install -r requirements-dev.txt
docker compose up -d db   # testy integracyjne wymagają bazy
pytest -v
ruff check .
```

## Konfiguracja

Aplikacja czyta konfigurację ze zmiennych środowiskowych (walidacja przy
starcie przez pydantic-settings) — patrz `.env.example`.