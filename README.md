# institute

Use this package when you need the `institute` command: the CI planner `swift-institute/.github` runs across the fleet, and the tools that keep the Institute's organizations on one policy. Run `institute --help` for its verbs. Start from `Institute.Organization` for the organizations and layers, `Institute.CI.Plan` for what CI schedules, and `Institute.CI.Validation` for what `ci -- package validate` checks. It neither clones, builds nor composes packages: each app owns its Xcode workspace, and a package builds with SwiftPM.

## Laws

- A change here reaches CI only through a new planner publication. `publish-planner.yml` builds the binaries at one revision, `institute planner canary` compares the candidate with the current planner on the canary repositories, and `institute planner adopt` records an adoptable candidate as a local commit in a `swift-institute/.github` checkout. Nothing is pushed for you.
- `.institute-ci-pin` and `.institute-ci-planner` are never edited by hand.
- `institute install` installs the binary CI pins, so the local command and CI's planner are one artifact.
- `Institute.Organization` is the only roster of organizations. A workflow that fans out over them reads it from `institute organizations`.
- Domain targets never parse arguments or write to the console, and `Institute Command` does nothing else. A new verb's logic goes in the domain target that owns its vocabulary.
- A source verdict of clean always means something was measured. swift-linter exits zero when no rules load or no files are scanned, so `ci -- source` checks every run against the engine's summary line and reports `UNMEASURED` when it is missing. There is no opt-out.
- `github token` prints the token and nothing else to standard output, and logs nothing. Whether it was minted or came from the cache goes to standard error. No diagnostic names the signing key.
- `Package.resolved` is generated. It is never committed, hand-edited or deleted to force resolution. Change `Package.swift` and resolve.
- The eight `Source …` targets are copied from swift-source at `9e419218900e171c0c66f76483994d89d7ef5816`, under the same license and copyright holder. Five files differ only in `map(Byte.init)` becoming `map(Byte.init(_:))`. The `Source` product itself comes from swift-molecules/swift-source.
