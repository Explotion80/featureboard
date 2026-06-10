# FeatureBoard AI Agent — starter kit (v2, scalony z Twoim CLAUDE.md)

System agentów AI analizujących repo FeatureBoard w trzech warstwach:

| Warstwa | Kiedy | Czym |
|---|---|---|
| **Lokalnie (Claude Code)** | na żądanie, w trakcie nauki | 4 subagenty + `/audit`, `/phase-review` |
| **CI (GitHub Actions)** | automatycznie przy każdym PR | `claude-pr-review.yml` |
| **Raz na fazę** | ręcznie z zakładki Actions | `claude-phase-review.yml` → raport jako Issue |
| **Claude.ai / Cowork** | analiza ad-hoc poza repo | Twój istniejący skill `devops-audit` |

## Co się zmieniło w v2 (po scaleniu z Twoim CLAUDE.md)

1. **CLAUDE.md = Twój prompt mentorski + warstwa agentowa.** Twoja treść jest
   nietknięta poza jednym wyjątkiem (punkt 3). Doszły sekcje: twarde konwencje,
   tryby pracy (mentor vs audyt — żeby pełny raport audytu nie gryzł się z
   zasadą "jeden krok na raz") i lista subagentów.
2. **Agenci znają Twój realny stack.** gitops-auditor sprawdza też Helm chart
   i Argo Rollouts (canary, AnalysisTemplate, auto-rollback); security-auditor
   dostał sekcję Terraform/GCP (stan w GCS, IAM, Workload Identity Federation,
   Cloud SQL private IP); fastapi-reviewer ma kalibrację "apka jest celowo
   banalna — nie gold-platuj"; roadmap-mentor zna fazy 0–8 i odróżnia punkty
   weryfikowalne w kodzie od punktów "Umiem wytłumaczyć..." (te zadaje Tobie
   jako pytania, nigdy nie odhacza ich sam).
3. **Sekcja `# Start` → `# Status`.** Powód: CLAUDE.md jest wczytywany na
   początku KAŻDEJ sesji, więc instrukcja "zacznij od Fazy 0" kazałaby
   Claude'owi wiecznie zaczynać od zera. Sekcja Status (aktualna faza /
   ostatni krok / następny krok) pełni rolę pamięci między sesjami —
   aktualizuj ją (lub każ Claude'owi aktualizować) na końcu sesji.
4. **ROADMAP.md wypełniony Twoimi fazami 0–8** z propozycją mierzalnych
   kryteriów "done" + punktami "Umiem wytłumaczyć..." pod rozmowy
   rekrutacyjne. To propozycja — przejrzyj i przytnij do swoich planów.

## Struktura

```
CLAUDE.md                          # mentor + konwencje + tryby + Status
ROADMAP.md                         # fazy 0-8 z definicjami done (źródło prawdy)
.claude/
  agents/
    gitops-auditor.md              # Helm, Kustomize, Argo CD, Rollouts, drift
    security-auditor.md            # Docker, K8s, Terraform/GCP, Actions, sekrety
    fastapi-reviewer.md            # kod aplikacji (bez over-engineeringu)
    roadmap-mentor.md              # postęp vs ROADMAP.md + sprawdzenie zrozumienia
  commands/
    audit.md                       # /audit [gitops|security|code]
    phase-review.md                # /phase-review <0-8>
.github/workflows/
  claude-pr-review.yml             # review każdego PR
  claude-phase-review.yml          # przegląd fazy (workflow_dispatch) → Issue
```

## Instalacja

1. Skopiuj zawartość do roota repo FeatureBoard (CLAUDE.md możesz podmienić —
   Twoja treść już w nim jest). Przejrzyj `ROADMAP.md` i dostosuj kryteria.
2. GitHub → Settings → Secrets and variables → Actions → dodaj
   `ANTHROPIC_API_KEY`. Albo w Claude Code: `/install-github-app`.
3. Test lokalny: `claude` w repo → `/audit`. Test CI: otwórz testowy PR.

## Użycie

- `/audit` — pełny audyt → `audits/AUDIT-<data>.md`; `/audit gitops` zawęża
  (analogicznie `security`, `code`)
- `/phase-review 0` — ocena fazy → `audits/PHASE-0-<data>.md`; kończy się
  pytaniami sprawdzającymi zrozumienie (zgodnie z Twoim kontraktem mentorskim)
- Subagenty odpalają się też proaktywnie po zmianach w odpowiednich plikach
- CI: PR review automatycznie (drafty pomijane, nowe commity anulują stary
  przebieg); przegląd fazy: Actions → "Claude Phase Review" → numer fazy
- Claude.ai: ten sam format severity co Twój skill `devops-audit`; dla
  spójności wrzuć `CLAUDE.md` + `ROADMAP.md` do projektu w Claude.ai

## Uwagi praktyczne

- **Windows:** subagenty wołają `helm`/`kustomize`/`kubeconform` przez Bash —
  miej je w PATH (Git Bash) albo odpalaj Claude Code w WSL. Gdy narzędzia
  brakuje, agent ma to odnotować, nie zmyślać wyniku renderu.
- **Koszty:** subagenty mają osobne konteksty (drożej niż pojedyncza sesja);
  pełny `/audit` to najdroższa operacja — stąd argument zawężający.
  W CI limity `--max-turns` (25/30) do regulacji.
- **Bezpieczeństwo:** wszystko read-only wobec kodu (agenci bez Write/Edit,
  CI z `contents: read`, whitelista pojedynczych komend `gh`). Efekty uboczne
  to tylko: komentarz w PR, Issue, pliki w `audits/`.
- **Język raportów:** po polsku; jeśli chcesz raporty w `audits/` po angielsku
  jako artefakt portfolio, zmień "in Polish" w plikach agentów.
- Kolejni agenci (np. `observability-auditor` pod fazę 7) = nowy plik
  w `.claude/agents/` wg tego samego wzorca.
