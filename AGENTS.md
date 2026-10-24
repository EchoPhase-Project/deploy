# AGENTS.md: EchoPhase deploy

The project's own EchoPhase instance: a single k3s node reconciled by Flux
from `main`. A change on `main` is live within a minute. Humans read
[CONTRIBUTING.md](CONTRIBUTING.md); this file is the short version for coding
agents. When the two disagree, CONTRIBUTING.md and the files win: fix this
file.

## Layout

- `clusters/dusty/`: Flux source and one Kustomization per app.
- `apps/echophase/`: chart pin (`chart.yaml`) and values (`helmrelease.yaml`).
- `apps/monitoring/`, `apps/weblate/`: internal tools.
- `infra/`: registry, Traefik, Woodpecker; applied by mise tasks, not Flux.
- `mise-tasks/`: everything run by hand (`mise tasks` lists them).

## Rules

- Secrets live only in `*.enc.yaml`, encrypted with SOPS. Never decrypt them
  to a file in the repository, print their values, or commit a secret in
  plaintext. Edit with `sops <file>`; to check a value, test for its presence,
  not its content.
- Do not edit the lines marked `# ci:image-tag <component>` in
  `apps/echophase/helmrelease.yaml`: CI commits them (`release: …`). Roll back
  with `git revert` of the release commit.
- Flux prunes: removing a manifest from `apps/` or `clusters/` deletes it from
  the cluster.
- Internal tools listen on `127.0.0.1` and are reached through the tailnet; do
  not expose them publicly.
- Every manifest opens with a comment saying what it is and which task applies
  it; keep it true.
- Pin chart and image versions.
- Do not run tasks that change the cluster (`*:install`, `*:expose`,
  `registry:gc`, `dev:down`, `flux:reconcile`) unless asked; `flux:status`,
  `helm:status` and `helm:history` are read-only.

## Checking a change

CI only checks commit messages. Validate manifests yourself:
`kubectl apply --dry-run=server -f <file>`, or `kubectl kustomize apps/<app>`
for plaintext parts. After merging, `mise run flux:status` shows whether Flux
applied it.

## Commits

Conventional Commits, checked in CI, scoped by app: `feat(monitoring): …`,
`fix(infra): …`. `release:` is for version changes.
