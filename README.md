# institute

The Institute domain model behind the central CI: workflow and repository policy, the CI
contract and validation, Institute lint over one package, and the installation of the pinned
planner — as a library, with no command surface of its own.

This package is the domain half of a split. The other half,
[swift-institute/institute-application](https://github.com/swift-institute/institute-application),
owns the `institute` executable, its command surface, and the composition that binds the two.
Domain semantics live here; the act of running them lives there.

## Targets

Each target owns one area and has its own change schedule. Every arrow points down, and there
are no cycles.

| Target | Owns |
|---|---|
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
| `Source Measurement`, `Source Profile`, `Source Report`, `Source Execution`, `Source Repair`, `Source Linter`, `Source Swift Format`, `Source SwiftLint` | The engine-neutral source measurement the Institute lint is built on |

## Using it

```swift
.package(url: "https://github.com/swift-institute/institute.git", branch: "main")
```

Then depend on the targets you need — the products carry the same names as the
targets above.

## Contributing

Open work lives in GitHub issues. Changes are pull requests, squash-merged, with
new behaviour covered by a test.
