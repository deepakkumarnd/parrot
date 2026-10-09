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

## Committing (strict)
- NEVER commit without the user's review. After making changes, stop, summarize
  what changed, and wait for the user to review the diff and explicitly ask for
  a commit.
- Approval covers only the changes it was given for. Later changes need a new
  review before they are committed.

## JavaScript
- Write all JavaScript (e.g. `lib/parrot/assets/*.js`, `skel/javascripts/*.js`)
  using ES6+ syntax: `const`/`let` instead of `var`, arrow functions, template
  literals, destructuring, and `class` where appropriate.
