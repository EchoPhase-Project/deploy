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
