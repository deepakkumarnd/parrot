# CLAUDE.md

## Branching (strict)
- ALWAYS create a new branch before working on a GitHub issue. Never commit
  issue work directly to `master`.
- Pick the branch prefix from the issue's GitHub label:
  - Label `feature` → `feat/{issue-number}-{feature-name}`
    (e.g. `feat/2-post-tags`).
  - Label `bug` → `fix/{issue-number}-{fix-name}`
    (e.g. `fix/7-broken-internal-links`).
- The name part is lowercase and kebab-case.
- If the issue has neither label, or has both, ask before creating the branch.
