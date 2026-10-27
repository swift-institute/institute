# institute

The `institute` command: the Swift Institute's central CI planner and the tools that keep its
GitHub organizations on one policy. The domain model lives in
[swift-institute/institute](https://github.com/swift-institute/institute); this package owns
the executable and its command surface.

| Command | What it does |
| --- | --- |
| `install` | Download the planner that `swift-institute/.github` pins, verify its digest, and install it as `~/.local/bin/institute`. Nothing is built. |
| `ci -- package validate\|plan\|aggregate` | The verbs the central `swift-ci.yml` runs: validate a subject repository, plan its job matrix, aggregate the verdict. |
| `ci -- source` | Institute lint over one checked-out package at an exact revision. CI's `Quality · source` job is the evidence; a local run is guidance. |
| `planner canary\|adopt` | Judge a `publish-planner` run against the current planner on the canary repositories, and commit an adoptable pin to the consumer checkout. |
| `repository …` | Repository policy across the organizations: caller workflows and the `.gitignore` canon. |
| `github token` | Mint a GitHub App installation token for one organization, optionally narrowed. |

## How CI uses it

`swift-institute/.github` names one exact revision of this repository in `.institute-ci-pin`,
and the published binaries for that revision in `.institute-ci-planner`. The `institute-ci`
action installs that binary, and `swift-ci.yml` calls only `institute ci`. A change here
reaches CI only through a new planner publication:

1. `publish-planner.yml` (manual) builds the binaries at one revision and uploads them to
   this repository's `ci-binaries` release.
2. `institute planner canary --publish-run <run>` measures the canary repositories with the
   current and the candidate planner and writes the comparison as evidence.
3. `institute planner adopt` records an adoptable candidate as a local commit in a
   `swift-institute/.github` checkout. Nothing is pushed.

`install` installs the same pinned binary on a Mac, so the local command and CI's planner
are one artifact.

## Where facts come from

- **Organizations and layers:** `swift-institute/.github`'s
  [`fleet.json`](https://github.com/swift-institute/.github/blob/main/.github/policy/fleet.json)
  and the GitHub organizations themselves. There is no second roster.
- **Local development:** each app owns its Xcode workspace and builds through Xcode. This
  command neither clones, builds, nor composes packages.

## Developing it

`institute control.xcworkspace` opens this package and `../institute` together, so a change
to the domain library builds with the command from the working copies. Build and test through
Xcode. `Package.resolved` is generated state and is never committed.

## License

See [LICENSE.md](LICENSE.md).
