# Contributing to EchoPhase deploy

This repository contains the EchoPhase instance of the project. The instance
is a single k3s node. [Flux](https://fluxcd.io) applies the state of `main` to
the node. To run EchoPhase yourself, use
[charts](https://github.com/EchoPhase-Project/charts). The rules for all
repositories are in the
[guide of the organisation](https://github.com/EchoPhase-Project/.github/blob/main/CONTRIBUTING.md).

A change goes live in less than one minute after it gets to `main`. Thus,
usually the maintainers make the changes. Pull requests that repair a
manifest, a comment, or a task are welcome. If a change has an effect on what
runs, open an issue first.

## Layout

| Path | Contents | Applied by |
|---|---|---|
| `clusters/dusty/` | Flux: the source (this repository) and one Kustomization for each app | Flux |
| `apps/echophase/` | EchoPhase: the published chart (`chart.yaml`) and its values (`helmrelease.yaml`) | Flux |
| `apps/monitoring/` | VictoriaMetrics, Tempo, Grafana, Gatus, GlitchTip, Umami | Flux |
| `apps/weblate/` | Weblate, where translators translate the web client | Flux |
| `infra/` | The image registry, Traefik settings, Woodpecker CI | mise tasks, manually |

Flux removes objects that are not in the repository. If you remove a manifest
from `apps/` or `clusters/`, Flux removes the object from the cluster. Flux
does not manage `infra/`. The mise tasks apply it.

## How releases arrive

- **Images.** Each push to `main` of server or webapp starts an image build in
  the cluster (Woodpecker). The build then commits `release: <component> <tag>`
  to this repository. This commit changes the line with the mark
  `# ci:image-tag <component>` in `apps/echophase/helmrelease.yaml`. Do not
  edit those lines manually. To go back to a previous release, run
  `git revert` on the release commit.
- **The chart.** `apps/echophase/chart.yaml` pins a version of the published
  chart. An upgrade is a change of one line. Renovate opens these changes as
  `release:` pull requests. Read the release notes of the chart before you
  merge.

## Secrets

Secrets are in `*.enc.yaml` files. [SOPS](https://getsops.io) and age encrypt
these files. SOPS encrypts only `data` and `stringData`, so the names and the
structure stay readable. Flux decrypts the files in the cluster.

> WARNING: Do not commit a secret as plain text, not even for a short time.
> Git keeps it in the history.

- To edit a secret file, run `sops <file>`. This command needs the private
  key.
- `apps/echophase/secret-values.example.yaml` shows the structure of the
  EchoPhase secret, without values.
- If you do not have the key, you cannot change secrets. Tell what you need
  in the pull request. A maintainer then adds it.

## Tasks

The project pins the tools (helm, kubectl, flux, sops, age, oras) with
[mise](https://mise.jdx.dev). Run `mise install --locked`, then `mise tasks`.
The tasks need access to the cluster. Put the settings of your computer in
`mise.local.toml`. Refer to `mise.local.toml.example`.

| Tasks | Purpose |
|---|---|
| `flux:status`, `flux:reconcile` | Show what Flux applied; apply `main` immediately |
| `helm:status`, `helm:history` | Show the EchoPhase release (read-only, because Flux owns it) |
| `dev:deploy`, `dev:status`, `dev:down` | A dev instance from local checkouts, adjacent to the real instance |
| `traefik:configure`, `registry:*`, `woodpecker:*` | The parts in `infra/` |
| `monitoring:*`, `weblate:*`, `tailscale:*` | Make the internal tools available in the tailnet, passwords, first configuration |

## Conventions

- Each manifest starts with a comment. The comment tells what the manifest
  is, why it has this configuration, and which task applies or exposes it.
  When you change the manifest, keep the comment correct.
- Internal tools (Grafana, Gatus, GlitchTip, Umami, the Woodpecker UI) listen
  only on `127.0.0.1`. Users get access to them through the tailnet. Do not
  make them available on the internet. Their public parts go through the
  webapp (`/errors`, `/stats/`).
- Pin chart versions and image versions. Renovate updates them.
- Commit messages follow Conventional Commits. CI examines them. Use the app
  as the scope (`feat(monitoring): …`, `fix(infra): …`). Use `release:` for
  version changes.

## Examine a change

CI examines only the commit messages. Thus, examine the manifests yourself
before you push:

- Run `kubectl apply --dry-run=server -f <file>` against the cluster. For the
  parts without encryption, you can run `kubectl kustomize apps/<app>`.
- After the merge, run `mise run flux:status` (or `flux get kustomizations`).
  It shows if Flux applied the change.
