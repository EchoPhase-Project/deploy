# 0002. A release does not wait for the GitHub checks

- Status: Accepted
- Date: 2026-11-24

## Context

A push to `main` of webapp or server starts two things at once: GitHub
Actions (tests, lint, contract, commit messages) and the Woodpecker release
(build the image, commit its tag here, Flux deploys it). So prod can get a
commit before its checks have a result.

A wait was built and tried (`ci:wait-checks`: poll the commit's Actions
runs, release only if all pass). It worked, and it made each release take
as long as the tests, 3–4 minutes instead of about 20 s.

The history of `Tests` on `main` (about the last 100 runs): webapp 55 of
55 green; server 45 green and 3 red, all from `dotnet format`, the OpenAPI
document check or the commit-message and image checks. None of the three
was a broken prod.

## Decision

- A release does not wait for GitHub Actions. If a commit is broken, it
  fails in prod and is reverted.
- The way back is `git revert` of the release commit here; Flux rolls back
  within a minute.

## Alternatives considered

- **Wait for all checks**: a red format or commit-message check would block
  a working fix, and every release would take 3–4 minutes.
- **Wait only for the tests that matter for prod** (the Linux test job):
  the same delay for a protection the history did not need.

## Consequences

- Releases stay fast: about 20 s after the image builds.
- Code that does not compile still never reaches prod: the image build
  fails first.
- Checks before the push (`mise run check`, `mise run lint`, `mise run
  test`) matter more; the repositories' agent rules already require them.
- If the project gets users for whom a broken minute is costly, revisit
  this: the wait described above can be restored as a first command of the
  release step.
