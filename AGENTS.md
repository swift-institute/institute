# institute — agent instructions

Read `README.md` first: it lists the commands, the targets, and how a change reaches CI.

## Building and testing

Open this package's directory through Xcode's connector. Every test target has its own scheme;
the `institute` scheme builds the executable and runs no tests.

## Where code goes

Domain targets never parse arguments or write to the console; `Institute Command` holds the
argument grammar and console output and nothing else. A new verb's logic goes into the domain
target that owns its vocabulary, and only its grammar and output into `Institute Command`.

## Gotchas

- **CI runs the pinned planner, not `main`.** A merged change does nothing in CI until a
  `publish-planner` run is canaried and adopted into `swift-institute/.github`'s
  `.institute-ci-pin`. Never edit the pin or `.institute-ci-planner` by hand.
- **`github token` mints a credential, so it prints one thing and logs nothing.** The token is
  the whole of stdout, so `GH_TOKEN=$(institute github token --org X)` captures a credential
  and nothing else; whether it was minted or served from cache goes to stderr. The App's private key
  and identity live in the login keychain (service = the bot's name, `--app`, default
  `swift-institute-bot`; account = the App id), are never compiled in or written to a file, and
  no diagnostic names the resolved key. Tokens are cached mode-600 per organization *and per
  permission set*, so a token narrowed to `contents=read` is never handed back for a request
  for the full grant. Preserve both properties in any change.
- **A source verdict of "clean" always means something was measured.** swift-linter exits zero
  when no rules load or no files are scanned. `ci -- source` adjudicates every run against the
  engine's summary line and reports `UNMEASURED`, never clean, when it is missing. There is no
  opt-out from measurement: every package receives the profile for its fleet lint bundle.
- **`Package.resolved` is generated state.** Never commit, hand-edit, or delete it to force
  resolution. Change `Package.swift` and resolve.

## Contributing

Open work lives in this repository's GitHub issues. New behaviour comes with a test that can
fail.
