# EchoPhase deploy

The project's own instance. To run EchoPhase yourself, use
[charts](https://github.com/EchoPhase-Project/charts): `helm install`, Docker
Compose, or its [Flux example](https://github.com/EchoPhase-Project/charts/tree/main/examples/flux)
for a GitOps repository of your own. This one is tied to the project's cluster
(its registry, keys and tools) and is not meant to be copied.

What runs in the cluster, reconciled by [Flux](https://fluxcd.io):

| Path | What |
|---|---|
| `clusters/dusty/` | Flux entry point for the k3s node `dusty` (source, kustomizations) |
| `apps/echophase/` | the EchoPhase `HelmRelease` (image tags, encrypted passwords) and the chart version (`chart.yaml`, from [charts](https://github.com/EchoPhase-Project/charts) on GHCR) |
| `infra/traefik/` | adjustments of k3s's Traefik: client addresses kept (`externalTrafficPolicy: Local`), so per-visitor rate limits and statistics work; `mise run traefik:configure` applies it |
| `apps/weblate/` | [Weblate](https://weblate.org) for the webapp's translations, with its Postgres and Valkey; host and passwords in `secrets.enc.yaml`. `mise run weblate:expose [--public]` serves it on the node's tailnet name, port 10000 |
| `apps/monitoring/` | VictoriaMetrics (metrics, with node-exporter and kube-state-metrics), Tempo (traces) and Grafana over both; the EchoPhase server sends them OTLP. Gatus checks every service (and the public webhook paths) each minute. GlitchTip collects the server's and the webapp's errors (`monitoring:glitchtip-bootstrap` creates its admin and projects once), Umami the webapp's visit statistics (`monitoring:umami-bootstrap` sets its admin password and website once). `mise run monitoring:expose` serves Grafana on the node's tailnet name, port 10001, Gatus on 10002, GlitchTip on 10003 and Umami on 10004; `monitoring:password`, `monitoring:glitchtip-password` and `monitoring:umami-password` print the admin logins |

Releasing is a commit here: Woodpecker writes the new image tag into
`apps/echophase/helmrelease.yaml` (the lines marked `# ci:image-tag`) and
Flux upgrades the release within a minute. Rolling back is `git revert`.

Passwords are in `apps/echophase/secret-values.enc.yaml`, encrypted with
[SOPS](https://getsops.io) for the age key in `.sops.yaml`:

```sh
sops apps/echophase/secret-values.enc.yaml   # edit (needs the private age key)
```

Flux decrypts with the same key, stored in the cluster as `flux-system/sops-age`.

## Bringing up the cluster from scratch

What Flux applies comes back by itself; what lives outside it (`infra/`, the
keys, the tailnet) and the first images need these steps, in this order.
Data is not part of it: the databases start empty (restore them from backups
if you have them).

### 0. Before you start

- A Linux node with [k3s](https://k3s.io) (its Traefik and service load
  balancer, as installed by default), and `~/.kube/config` pointing at it
  (copy `/etc/rancher/k3s/k3s.yaml`).
- [Tailscale](https://tailscale.com) on the node, logged in, with HTTPS and
  Funnel allowed for it in the tailnet's settings.
- The tools: `mise install --locked` in this checkout, plus `gh` logged in as
  an admin of EchoPhase-Project and Docker.
- The private age key of `.sops.yaml` at `~/.config/sops/age/keys.txt` (from
  your backup: without it no secret here can be decrypted).
- `mise.local.toml` from `mise.local.toml.example`: `WOODPECKER_SERVER`
  (`https://<node>.<tailnet>.ts.net:9443`, any port but 443) and a GitHub OAuth
  app for Woodpecker (callback `<WOODPECKER_SERVER>/authorize`).

### 1. Registry and Traefik

```sh
mise run registry:install      # localhost:30500, where CI pushes the images
mise run traefik:configure     # keep client addresses (externalTrafficPolicy: Local)
```

### 2. Flux

```sh
mise run flux:install          # controllers, the SOPS key, clusters/dusty
mise run flux:status
```

Flux now installs everything under `apps/`: monitoring and Weblate come up;
EchoPhase waits (`ImagePullBackOff`) until its images are in the registry.

### 3. Woodpecker

```sh
mise run woodpecker:install
mise run tailscale:expose      # the UI in the tailnet, only /api/hook public
mise run tailscale:check       # GitHub must reach the webhook through Funnel
```

Open `WOODPECKER_SERVER`, sign in with GitHub, enable the repositories server
and webapp, and create a personal access token (user settings). Put it in
`mise.local.toml` as `WOODPECKER_TOKEN`, then:

```sh
mise run woodpecker:deploy-key # lets the pipelines commit releases here
```

### 4. The first images

Run the release pipeline of each, from its checkout (with
`WOODPECKER_SERVER` and `WOODPECKER_TOKEN` in its own `mise.local.toml`):

```sh
mise run ci:run                # in server, then in webapp
```

Each builds its image into the registry and commits `release: …` here; Flux
then starts EchoPhase. Alternatively, `mise run registry:migrate --from
<registry>` copies the images from another registry.

### 5. Monitoring and errors

```sh
mise run monitoring:glitchtip-bootstrap   # prints the DSNs of server and webapp
mise run monitoring:umami-bootstrap       # prints the website id
mise run monitoring:expose                # Grafana, Gatus, GlitchTip, Umami in the tailnet
mise run weblate:expose                   # Weblate in the tailnet
```

A new GlitchTip and Umami mean new keys: put the server's DSN in
`apps/echophase/secret-values.enc.yaml` (`sops`, `echophase.extraEnv.SENTRY_DSN`),
the webapp's DSN and the website id in `apps/echophase/helmrelease.yaml`
(`webapp.extraEnv`), and push.

### 6. Check

```sh
mise run flux:status           # every kustomization and release Ready
```

Gatus (`:10002`) shows every service green once the site answers.
