# AGENTS.md: EchoPhase deploy

This repository contains the EchoPhase instance of the project. The instance
is a single k3s node. Flux applies the state of `main` to the node. A change
on `main` goes live in less than one minute. The full rules for persons are in
[CONTRIBUTING.md](CONTRIBUTING.md). This file is the short version for coding
agents. If this file and CONTRIBUTING.md are different, CONTRIBUTING.md and the
files are correct. Then correct this file.

## Layout

- `clusters/dusty/`: the Flux source and one Kustomization for each app.
- `apps/echophase/`: the chart version (`chart.yaml`) and the values
  (`helmrelease.yaml`).
- `apps/monitoring/`, `apps/weblate/`: internal tools.
- `infra/`: the registry, Traefik, and Woodpecker. Mise tasks apply these
  manifests. Flux does not apply them.
- `mise-tasks/`: all tasks that persons run manually. To see the list, run
  `mise tasks`.

## Rules

### Secrets

- Keep secrets only in `*.enc.yaml` files. SOPS encrypts these files.
- Do not decrypt a secret to a file in the repository.
- Do not show the values of secrets.
- Do not commit a secret as plain text.
- To edit a secret file, run `sops <file>`.
- To examine a secret, make sure that the value is present. Do not read the
  value.

### Image tags

- Do not edit the lines with the mark `# ci:image-tag <component>` in
  `apps/echophase/helmrelease.yaml`. CI commits these lines (`release: …`).
- To go back to a previous release, run `git revert` on the release commit.

### Manifests

- Flux removes objects that are not in the repository. If you remove a
  manifest from `apps/` or `clusters/`, Flux deletes the object from the
  cluster.
- Each manifest starts with a comment. The comment tells what the manifest is
  and which task applies it. Keep this comment correct.
- Pin all chart versions and image versions.

### Network

- Internal tools listen on `127.0.0.1`. Users get access to them through the
  tailnet. Do not make them public.

### Cluster tasks

- Some tasks change the cluster: `*:install`, `*:expose`, `registry:gc`,
  `dev:down`, `flux:reconcile`. Do not run these tasks if the user did not
  tell you to run them.
- These tasks only read data: `flux:status`, `helm:status`, `helm:history`.

## Examine a change

CI only examines commit messages. Thus, you must validate the manifests:

- Run `kubectl apply --dry-run=server -f <file>`.
- For parts without encryption, you can also run
  `kubectl kustomize apps/<app>`.

After the merge, run `mise run flux:status`. This task shows if Flux applied
the change.

## Commits

Use Conventional Commits. CI examines the commit messages.

- Use the app as the scope: `feat(monitoring): …`, `fix(infra): …`.
- Use `release:` only for version changes.
