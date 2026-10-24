# Contributing to EchoPhase deploy

This repository is what runs the project's own EchoPhase instance: a single
k3s node reconciled by [Flux](https://fluxcd.io) from `main`. To run EchoPhase
yourself, use [charts](https://github.com/EchoPhase-Project/charts) instead.
What is common to every repository is in the
[organisation's guide](https://github.com/EchoPhase-Project/.github/blob/main/CONTRIBUTING.md).

Changes here go live within a minute of reaching `main`, so most of them come
from the maintainers. Pull requests that fix a manifest, a comment or a task
are welcome; for anything that changes what runs, open an issue first.

## Layout

| Path | What | Applied by |
|---|---|---|
| `clusters/dusty/` | Flux: the source (this repository) and one Kustomization per app | Flux |
| `apps/echophase/` | EchoPhase: the published chart (`chart.yaml`) and its values (`helmrelease.yaml`) | Flux |
| `apps/monitoring/` | VictoriaMetrics, Tempo, Grafana, Gatus, GlitchTip, Umami | Flux |
| `apps/weblate/` | Weblate, where the web client is translated | Flux |
| `infra/` | the image registry, Traefik settings, Woodpecker CI | mise tasks, by hand |

Flux prunes: a manifest removed from `apps/` or `clusters/` is removed from the
cluster. `infra/` is not managed by Flux; its tasks apply it.

## How releases arrive

- **Images.** Each push to `main` of server or webapp builds its image in the
  cluster (Woodpecker) and commits `release: <component> <tag>` here, changing
  the line marked `# ci:image-tag <component>` in
  `apps/echophase/helmrelease.yaml`. Do not edit those lines by hand; to roll
  back, `git revert` the release commit.
- **The chart.** `apps/echophase/chart.yaml` pins a version of the published
  chart. Upgrading it is a one-line change (Renovate proposes them as
  `release:` pull requests); read the chart's release notes first.

## Secrets

Secrets live in `*.enc.yaml` files, encrypted with [SOPS](https://getsops.io)
and age; only their `data` and `stringData` are encrypted, so names and
structure stay readable. Flux decrypts them in the cluster.

- Edit one with `sops <file>` (needs the private key).
- `apps/echophase/secret-values.example.yaml` shows the structure of the
  EchoPhase secret, without values.
- Never commit a secret in plaintext, not even briefly: Git keeps it.
- Without the key you cannot change secrets; describe what you need in the
  pull request and a maintainer adds it.

## Tasks

Tools (helm, kubectl, flux, sops, age, oras) are pinned with
[mise](https://mise.jdx.dev): `mise install --locked`, then `mise tasks`.
The tasks need access to the cluster; machine settings go in
`mise.local.toml` (see `mise.local.toml.example`).

| Tasks | What |
|---|---|
| `flux:status`, `flux:reconcile` | what Flux applied; apply `main` now instead of within a minute |
| `helm:status`, `helm:history` | the EchoPhase release (read-only: Flux owns it) |
| `dev:deploy`, `dev:status`, `dev:down` | a dev instance from local checkouts, beside the real one |
| `traefik:configure`, `registry:*`, `woodpecker:*` | the parts under `infra/` |
| `monitoring:*`, `weblate:*`, `tailscale:*` | expose the internal tools in the tailnet, passwords, first setup |

## Conventions

- Every manifest opens with a comment saying what it is, why it is set up this
  way, and which task applies or exposes it. Keep it true when you change the
  manifest.
- Internal tools (Grafana, Gatus, GlitchTip, Umami, the Woodpecker UI) listen on
  `127.0.0.1` only and are reached through the tailnet, never the internet.
  Their public parts go through the webapp (`/errors`, `/stats/`).
- Pin chart and image versions; Renovate updates them.
- Commit messages follow Conventional Commits, checked in CI, with a scope for
  the app (`feat(monitoring): …`, `fix(infra): …`). `release:` is for version
  changes.

## Checking a change

CI checks only commit messages, so check manifests yourself before pushing:

- `kubectl apply --dry-run=server -f <file>` against the cluster, or
  `kubectl kustomize apps/<app>` for the plaintext parts;
- after merging, `mise run flux:status` (or `flux get kustomizations`) shows
  whether Flux applied it.
