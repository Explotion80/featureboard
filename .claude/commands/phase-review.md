---
description: Przegląd fazy roadmapy FeatureBoard (mentoring + ocena portfolio)
argument-hint: <numer fazy 0-8>
---

Use the **roadmap-mentor** subagent to review phase $ARGUMENTS of ROADMAP.md
against the actual state of this repository.

Requirements for the subagent run:
- Evidence-based: every status must cite a file path or commit.
- Include the tutorial-grade vs production-grade assessment.
- End with exactly 3 next actions and 3 interview questions.

Save the report to `audits/PHASE-$ARGUMENTS-<YYYY-MM-DD>.md` (create the
directory if needed) and print the "Następne kroki" section in the chat.
Report language: Polish.
