# institute

The `institute` command: the Swift Institute's central CI planner and the tools that keep its
GitHub organizations on one policy, together with the domain model behind them — workflow and
repository policy, the CI contract and validation, Institute lint over one package, and the
installation of the pinned planner.

| Command | What it does |
| --- | --- |
| `install` | Download the planner that `swift-institute/.github` pins, verify its digest, and install it as `~/.local/bin/institute`. Nothing is built. |
| `ci -- package validate\|plan\|aggregate` | The verbs the central `swift-ci.yml` runs: validate a subject repository, plan its job matrix, aggregate the verdict. |
| `ci -- source` | Institute lint over one checked-out package at an exact revision. CI's `Quality · source` job is the evidence; a local run is guidance. |
| `planner canary\|adopt` | Judge a `publish-planner` run against the current planner on the canary repositories, and commit an adoptable pin to the consumer checkout. |
| `repository …` | Repository policy across the organizations: caller workflows and the `.gitignore` canon. |
| `github token` | Mint a GitHub App installation token for one organization, optionally narrowed. |
| `version tag` | Tag each package's `main` head that passed CI with its next development version (`0.0.N` from `0.0.100`); `--backfill` tags only repositories not yet on the line, `--dry-run` writes nothing. `swift-institute/.github`'s `version-tags.yml` runs it. |

## Targets

Each target owns one area. Every arrow points down, and there are no cycles. Domain targets
never parse arguments or write to the console; `Institute Command` does nothing else.

| Target | Owns |
|---|---|
| `Institute CLI` | The `institute` executable: `main.swift` only |
| `Institute Command` | The argument grammar and console output of every verb |
| `Institute Planner` | The published planner: pins, releases, evidence, the canary and adoption |
| `Institute Version` | Development version tags: the version line, the CI gate a commit must pass, and the sweep that tags each `main` head |
| `Institute GitHub` | The GitHub transport the planner reads releases and contents through |
| `Institute Model` | The `Institute` namespace and its error, and the processor-count default for bounded fan-out |
| `Institute Installation` | Installing a verified planner binary into the account and the link-materialization contract it uses |
| `Institute CI Model` | The CI vocabulary: subjects, events, platforms, plans, verdicts |
| `Institute CI Canon` | The canonical documents every repository carries, such as the `.gitignore` classes |
| `Institute CI Contract` | The planner contract: what a plan and an aggregate must say |
| `Institute CI Workflow` | The GitHub Actions workflow vocabulary |
| `Institute CI Inventory` | What a checked-out repository contains, as CI reads it |
| `Institute CI Validation` | The validation rules `ci -- package validate` applies |
| `Institute Repository Policy` | Caller workflows and fleet policy across the organizations |
| `Institute Source Policy`, `Institute Source Profile`, `Institute Source Workspace`, `Institute Source` | Institute lint: the pinned engines and profiles, the package subject, and one measurement |
| `Source Measurement`, `Source Profile`, `Source Report`, `Source Execution`, `Source Repair`, `Source Linter`, `Source Swift Format`, `Source SwiftLint` | The engine-neutral source measurement the Institute lint is built on (see `VENDORED-SOURCE.md`) |

A macOS front end, when it comes, is its own package under `App/` that depends on this one by
path (`Institute Feature`, `Institute SwiftUI`, and its host under `App/Hosts/Institute`), so
SwiftUI and its stack never enter the planner's build or its pinned dependency graph.

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

Open this package's directory in Xcode and build and test there. `Package.resolved` is
generated state and is never committed.

## License

See [LICENSE.md](LICENSE.md).
