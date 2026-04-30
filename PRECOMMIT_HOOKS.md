# Pre-commit hooks

Audit reference: **IN-M1** (2026-04-19 infra audit). We enforce client-side secret
scanning with [gitleaks](https://github.com/gitleaks/gitleaks) so we don't ship
another `POSTGRES_PASSWORD` into a public repo.

## One-time setup

```bash
# 1. Install pre-commit itself (Python tool, runs the hooks)
pipx install pre-commit            # recommended
# or:  pip install --user pre-commit

# 2. Install hooks into every repo that has a .pre-commit-config.yaml
cd /opt/projects/fivucsas
./.pre-commit-install
```

That runs `pre-commit install` in the parent repo and in each submodule that
ships a config.

## What runs on commit

- **Parent repo, identity-core-api, web-app, client-apps**: gitleaks only.
- **biometric-processor**: gitleaks + trailing-whitespace + check-yaml + black +
  isort + mypy + pylint (Python stack was already configured).

## Bypass (do not)

`git commit --no-verify` will skip hooks. Per repo feedback rules we do not
bypass hooks without explicit user approval. If a hook misfires, fix the
finding or update the tool revision rather than bypassing.

## Updating the gitleaks version

Bump the `rev:` field in each `.pre-commit-config.yaml` and run
`pre-commit autoupdate` inside the affected repo, then commit the change.

## CI mirror

GitHub push-protection (server-side secret scan) is Phase C5 and **not yet
enabled** as of 2026-04-19. Client-side gitleaks is the only enforcement until
then.
