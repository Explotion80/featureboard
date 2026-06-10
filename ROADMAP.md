# FeatureBoard — Roadmapa (fazy 0–8)

> Źródło prawdy dla agenta `roadmap-mentor` i dla zamykania faz. Każdy punkt
> "Definicja done" jest kryterium weryfikowalnym w repo. Dostosuj śmiało —
> to propozycja DoD wygenerowana z Twojej roadmapy, nie świętość.

## Faza 0 — Aplikacja FastAPI + testy
**Cel:** banalna, ale poprawnie napisana "paczka" do dalszej maszynerii.
**Definicja done:**
- [ ] Endpointy `/` (czyta `ENVIRONMENT` i `APP_VERSION` z env) i `/health`
- [ ] CRUD notatek na PostgreSQL (SQLAlchemy 2.0 async + Alembic)
- [ ] Konfiguracja przez `pydantic-settings` (zero wartości zaszytych w kodzie)
- [ ] Testy pytest (httpx) przechodzą lokalnie; `ruff check .` czysty
- [ ] Umiem wytłumaczyć: po co osobny `/health`, skąd apka zna swoje środowisko

## Faza 1 — Docker + docker-compose
**Cel:** powtarzalne środowisko lokalne, obraz gotowy pod rejestr.
**Definicja done:**
- [ ] Dockerfile multi-stage, non-root USER, przypięty base image, `.dockerignore`
- [ ] `docker compose up` stawia apkę + Postgres z healthcheckami i wolumenem
- [ ] Obraz odpala się też samodzielnie (`docker run`) z configiem przez env
- [ ] Umiem wytłumaczyć: co daje multi-stage, czemu non-root, co robi healthcheck

## Faza 2 — CI: GitHub Actions
**Cel:** każda zmiana przechodzi przez bramkę jakości, obraz ląduje w rejestrze.
**Definicja done:**
- [ ] Workflow na PR: ruff + pytest (+ cache zależności)
- [ ] Na main: build obrazu, skan (np. Trivy), push do Artifact Registry z tagiem = git SHA
- [ ] Auth do GCP przez Workload Identity Federation (brak kluczy JSON w sekretach)
- [ ] `permissions:` w workflow ograniczone do minimum; akcje 3rd-party przypięte
- [ ] Umiem wytłumaczyć: przepływ OIDC GitHub→GCP i czemu to lepsze niż klucz SA

## Faza 3 — Terraform: infrastruktura GCP
**Cel:** infra odtwarzalna z kodu, stan zarządzany zdalnie.
**Definicja done:**
- [ ] Backend stanu w GCS (z wersjonowaniem bucketa)
- [ ] GKE + Cloud SQL (Postgres, prywatne IP) + IAM least-privilege z kodu
- [ ] Decyzja GKE Autopilot vs Standard podjęta i opisana (tradeoffy) w README/ADR
- [ ] `terraform fmt -check` i `validate` w CI; zero sekretów w `.tf`/`.tfvars` w repo
- [ ] Umiem wytłumaczyć: co jest w state, czemu zdalny backend, co robi Workload Identity

## Faza 4 — Kubernetes: Helm chart + Kustomize
**Cel:** własny chart aplikacji + warstwa per-środowisko.
**Definicja done:**
- [ ] Własny Helm chart: Deployment, Service, ConfigMap, probes, resources,
      securityContext — wszystko sterowane z `values.yaml`
- [ ] `helm lint` i `helm template` czyste; chart wersjonowany w `Chart.yaml`
- [ ] Kustomize base + overlaye dev/staging/prod; `kustomize build` przechodzi dla każdego env
- [ ] Apka na klastrze pokazuje poprawny `ENVIRONMENT` per overlay
- [ ] Umiem wytłumaczyć: podział ról Helm vs Kustomize w TYM repo i czemu oba

## Faza 5 — Argo CD: GitOps z promocją
**Cel:** klaster trzyma stan z gita, promocja dev→staging→prod przez PR.
**Definicja done:**
- [ ] Argo CD na klastrze; app-of-apps; Application per środowisko
- [ ] dev: automated sync (prune+selfHeal); prod: sync świadomie bramkowany
- [ ] Promocja wersji = zmiana taga obrazu w overlayu przez PR (opisana w README)
- [ ] Sekrety przez External Secrets Operator + GCP Secret Manager (zero plaintext)
- [ ] Umiem wytłumaczyć: pull vs push deployment, co się dzieje przy driftcie

## Faza 6 — Argo Rollouts: canary z auto-rollbackiem
**Cel:** wdrożenie progresywne sterowane metrykami.
**Definicja done:**
- [ ] Deployment zastąpiony Rolloutem ze strategią canary (kroki + pauzy)
- [ ] AnalysisTemplate na metryce z Prometheusa (np. error-rate) decyduje o promocji
- [ ] Zademonstrowany automatyczny rollback po wdrożeniu "zepsutej" wersji
      (zrzuty/nagranie w docs/ — to złoto na rozmowę)
- [ ] Umiem wytłumaczyć: canary vs blue-green vs rolling i kiedy co

## Faza 7 — Observability + symulacja awarii
**Cel:** widzę, mierzę i alarmuję; umiem przejść od alertu do przyczyny.
**Definicja done:**
- [ ] kube-prometheus-stack; apka eksportuje `/metrics` (instrumentator FastAPI)
- [ ] Dashboard Grafany dla apki (RPS, latencja, błędy, zasoby)
- [ ] Loki zbiera logi (JSON) z apki; logi skorelowane z metrykami
- [ ] Min. 2 sensowne alerty; symulacja awarii + krótki runbook w docs/
- [ ] Umiem wytłumaczyć: cztery złote sygnały i ścieżkę alert→dashboard→logi

## Faza 8 — Capstone AI: alert → diagnoza LLM
**Cel:** wisienka: automat streszczający przyczynę alertu i sugerujący fix.
**Definicja done:**
- [ ] Webhook Alertmanagera → mały serwis → LLM → podsumowanie (Slack/Issue)
- [ ] Serwis dostaje kontekst (alert + ostatnie logi/metryki), klucz API w Secret Managerze
- [ ] Przykładowy incydent end-to-end udokumentowany w docs/
- [ ] Umiem wytłumaczyć: co LLM dostaje na wejściu, ograniczenia i ryzyka podejścia
