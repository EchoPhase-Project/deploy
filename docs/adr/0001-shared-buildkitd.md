# 0001. One BuildKit daemon with a state for CI and dev builds

- Status: Accepted
- Date: 2026-11-24

## Context

Each Woodpecker image step started `buildctl-daemonless.sh`: a fresh
BuildKit in a new, privileged pod, with no state. Its only cache was the
registry (`:buildcache` tags), so even a full cache hit downloaded and
unpacked the layers again, and every build exported its cache back:

- webapp: about 42 of a 64 s image step went to getting the cached
  `node_modules` back; the release took about 105 s;
- server: about 120 of 228 s went to pulling the .NET base images again and
  exporting the cache (72 s); the release took about 270 s.

`dev:deploy` built with the node's Docker instead, whose build cache had no
limit and had grown to 40 GB, part of a disk that reached 92 %.

## Decision

- One long-lived `buildkitd` (`infra/woodpecker/buildkitd.yaml`): a
  StatefulSet in the `woodpecker` namespace with a 20 Gi volume, GC that
  keeps 15 GB, and a NetworkPolicy that lets in only pipeline pods.
- The image steps are only `buildctl` clients: no privileges, no registry
  cache import or export. They wait up to 10 s for the NetworkPolicy to let
  a new pod through.
- No CPU limit (MSBuild sees all 16 cores; 4 cores throttled it in 3 of 5
  periods, 8 cores in 2 of 5). Memory is limited to 10 Gi, because the page
  cache of the layer store counts.
- `dev:deploy` builds on the same daemon through a `kubectl port-forward`
  and pushes to the registry's Service; the node's Docker is not used.
- The server's contract (`openapi.json`) comes from the same build
  (Dockerfile target `contract`), not from a second Debug build.

## Alternatives considered

- **A volume for `/var/lib/buildkit` mounted into each step's pod**: one
  build at a time per volume, and still a daemon start per step.
- **Keep the registry cache, with `mode=min`**: saves most of the export,
  but `dotnet restore` and `npm ci` then run on every build.
- **A daemon per repository**: two caches and two limits for builds that
  share base images.
- **Keep a CPU limit** (8 cores): protects prod a little during a build,
  but `dotnet publish` stayed throttled; builds are short and the
  applications' CPU requests stay reserved.

## Consequences

- Warm pipelines take 15–20 s; a server release with a code change about
  75–97 s (the build itself).
- The cache is one place with one limit: CI and dev builds share it, and
  Docker on the node no longer grows.
- A build can take all the node's CPU for its duration.
- `buildkitd` is a single pod: if it is down, no image builds. Its cache
  occasionally misses a layer for no reason found yet (`npm ci` again,
  35–60 s).
- `woodpecker:install` applies the manifest; `buildctl` comes from mise in
  the same version as the daemon.
