# institute

The Institute domain model: what is true about an Institute checkout, its
inventory, its dependencies, its pages and its instruments — as a library, with
no command surface of its own.

This package is the domain half of a split. The other half,
[swift-institute/institute-application](https://github.com/swift-institute/institute-application),
owns *operating* an Institute: the `institute` executable, its command surface,
and the composition that binds the two. Domain semantics live here; the act of
running them lives there.

## Targets

Each target owns one area and has its own change schedule. The dependency order
below is the real one — every arrow points down, and there are no cycles.

| Target | Owns |
|---|---|
| `Institute Model` | The checkout's vocabulary: root, layout, layer, repository, selection, peers, configuration, errors, receipts, inspections |
| `Institute Inventory` | The name → organization → path authority, its discovery, merge and writing |
| `Institute Dependency` | Manifest dependency origins, ownership policy, the audit and its report |
| `Institute Development` | Working in a checkout: sync, composition, the generated Xcode workspace, navigation, context projection, installation |
| `Institute Lint` | Lint measurement, adjudication, the ledger, the sweep and its exit policy |
| `Institute Pages` | The authored-page inventory: READMEs, DocC catalogues, organization profiles |
| `Institute Doctor` | Executed checks over the checkout, and the report they produce |
| `Institute Conversion` | The conversion instrument: cohorts, trials, seals and receipts |
| `Institute Instruments` | Ecosystem coherence and verification runs over the whole selection |
| `Build Coordinator` | Machine-lock-serialized SwiftPM and `xcodebuild` invocation with fresh-scratch evidence builds |

`Build Coordinator` is carried here because `Institute Development` and
`Institute Instruments` both build through it. It is a general mechanism with no
Institute vocabulary in it and is due to extract to its own package; it sits here
until it does.

## Using it

```swift
.package(url: "https://github.com/swift-institute/institute.git", branch: "main")
```

Then depend on the targets you need — the products carry the same names as the
targets above.

## Contributing

Open work lives in GitHub issues. Changes are pull requests, squash-merged, with
new behaviour covered by a test.
