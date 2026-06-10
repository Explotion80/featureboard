---
description: Pełny audyt repo FeatureBoard (GitOps + security + FastAPI) z raportem zbiorczym
argument-hint: [gitops|security|code] (opcjonalnie — zawęża zakres)
---

Run a full audit of this repository.

Scope: if "$ARGUMENTS" is non-empty, run only the matching part
(gitops → gitops-auditor, security → security-auditor, code → fastapi-reviewer).
Otherwise run all three.

1. Use the **gitops-auditor** subagent to audit Kustomize overlays, Argo CD
   applications and environment drift.
2. Use the **security-auditor** subagent to audit Docker, Kubernetes manifests,
   GitHub Actions and app configuration.
3. Use the **fastapi-reviewer** subagent to review the application code.

Then consolidate: merge the three reports into ONE document, deduplicate
overlapping findings (keep the higher severity), and order sections
Critical → Warning → Info → Co jest dobrze. Add a 5-line executive summary at
the top (overall health, counts per severity, top 3 fixes by impact).

Save the consolidated report to `audits/AUDIT-<YYYY-MM-DD>.md` (create the
directory if needed) and print the executive summary in the chat. Report
language: Polish.
