# Vendored Source targets

Eight targets in `Sources/` are copied unchanged from the archived repository
https://github.com/swift-compositions/swift-source at revision
9e419218900e171c0c66f76483994d89d7ef5816:

- `Sources/Source Measurement`
- `Sources/Source Profile`
- `Sources/Source Swift Format`
- `Sources/Source SwiftLint`
- `Sources/Source Linter`
- `Sources/Source Execution`
- `Sources/Source Report`
- `Sources/Source Repair`

## Licence and attribution

The upstream repository is licensed under the Apache License, Version 2.0, with
the notice "Copyright 2025 Coen ten Thije Boonkkamp". Its `LICENSE.md` is
byte-identical to this repository's `LICENSE.md`, which therefore covers the
copied files. The upstream repository has no NOTICE file, and the copied files
carry no licence headers.

## Modifications

Five source files carry one mechanical change each, marked "modified" in the
table below. `map(Byte.init)` becomes `map(Byte.init(_:))`, because the live
swift-atoms/swift-byte `Byte` now also has `init(bitPattern:)`, which made the
unlabelled reference ambiguous. It is the same initializer upstream called, so
behaviour and serialization are unchanged. The other source files are unmodified.
The remaining changes are in `Package.swift`:

- The targets' dependency on the upstream package's own `Source` target is
  replaced by the `Source` product of https://github.com/swift-molecules/swift-source,
  which that upstream target re-exported. There is one `Source` module in the graph.
- Their other dependencies are unchanged: `Diagnostic` (swift-molecules/swift-diagnostic),
  `JSON` (swift-compositions/swift-json) and `FIPS 180-4` (swift-standards/swift-fips-180-4).
- Their upstream Swift settings are kept: this package's settings loop plus
  `Lifetimes` and `InferIsolatedConformances` (`vendoredSourceSettings`).
- The targets are not products of this package. `Institute Source` depends on all eight.

## Not copied

- The upstream `Source` target (`Source.Loader`, `Source.Cache`, `Source.Error` and
  a re-export of the live `Source`). Nothing in the eight targets, this package or
  swift-institute/institute-application references `Loader`, `Cache` or `Error`;
  copying it would add a second module named `Source`.
- `Source Test Support` and the upstream tests. Neither this package nor
  institute-application uses them.

This copy makes no compatibility claim for the archived package's public API
beyond these eight modules.

## File hashes (SHA-256)

| File | Upstream | Here |
|---|---|---|
| `Sources/Source Execution/Source.Execution+measurement.swift` | `45e47b38bd60e7f6fc3f04e421a0ddc76c4bc1cc4d11e12623eb31c784045cca` | same |
| `Sources/Source Execution/Source.Execution.Error.swift` | `ccbb0e4570471dc9d13ee262490195109ea2fff5a6b232cab5349265813df8b8` | same |
| `Sources/Source Execution/Source.Execution.swift` | `1b460ebdfda88e18360ba25f982ca5bfd383aca1086bb66cdf73464f69cbc875` | same |
| `Sources/Source Execution/exports.swift` | `c8fd7705129f7edc1d6b08d5ad3bd596bd157fef89e477ee258a5a1e03503241` | same |
| `Sources/Source Linter/Source.Engine.Driver+linter.swift` | `0fa949e3248b701f48eaa6259f8be7621a47f10622ea777f272de67d57c2cf96` | same |
| `Sources/Source Linter/Source.Measurement+linter.swift` | `598af22fc62c566342fe89ae10e6211d210641384ca54979e14fcad7f1e1e2ed` | same |
| `Sources/Source Linter/exports.swift` | `8e918706d0b1f3b4281080eee4383e9d2fd913fe52d2671d9cfa9095bbfcc147` | same |
| `Sources/Source Measurement/Source.Artifact.Digest.swift` | `05d259049f469310ff6e93db303ca40babe72b8b291e4f1b950bfe8574fe95df` | same |
| `Sources/Source Measurement/Source.Artifact.Evidence.swift` | `14f0a672fb35c3d573979df829c0609dfae24958d15da900b19bac5cbf982e4f` | same |
| `Sources/Source Measurement/Source.Artifact.Identity.swift` | `6a3e8e409bd73e76424fcd2ea7371797e6e023133873454ad152bd6844960225` | same |
| `Sources/Source Measurement/Source.Artifact.Kind.swift` | `b83d9031d0fdcd0f5ceb9b1ec4860474f5ada24de276b933076a4270adfb490b` | same |
| `Sources/Source Measurement/Source.Artifact.Provenance.Generated.swift` | `830a1fdf8b7e7d748ece4f4711bd0b8c3065004bf8c0b489aac8c8f19a82dc2d` | same |
| `Sources/Source Measurement/Source.Artifact.Provenance.Owner.swift` | `f2033de7597bd917a05148007297640bbe18b61db9732c5ed3314f3110ff700f` | same |
| `Sources/Source Measurement/Source.Artifact.Provenance.swift` | `d32923d424480c94a49c75f9fac2b9934288c44993e7993bc43ff1d4ec619367` | same |
| `Sources/Source Measurement/Source.Artifact.Purpose.Control.Expectation.swift` | `7bcd7ee36bd7221a0deb6ab04147755578a505f6f93e294bf0ff2cd826735365` | same |
| `Sources/Source Measurement/Source.Artifact.Purpose.Control.swift` | `fcb748531f64f5de1afec240b4329ad0f76c474e581108b9a6e63276572453dc` | same |
| `Sources/Source Measurement/Source.Artifact.Purpose.swift` | `30d784a05abe4fc030ceb0e44570f2db7cb7d28e5e021ca5194e20215f81d5b9` | same |
| `Sources/Source Measurement/Source.Artifact.Schema.swift` | `290e5c1eeffcf607236f90afc41411fa4a71e79003202a2e73b03f76dcfdc6ae` | same |
| `Sources/Source Measurement/Source.Artifact.Verdict.swift` | `4b5da76882b68a9c76b4d9d12db58332f3dd3046c6984d930ebb3c65511a79e8` | same |
| `Sources/Source Measurement/Source.Artifact.swift` | `5398b41dc886d9d210dd7363fe4a8aabf2b16b1aa5cdee6d71da0fa6b7ee0099` | same |
| `Sources/Source Measurement/Source.Engine.ID.swift` | `3657fe1f0f04953b4810388c28c26efbe609dbc828a93d824967fd6d38c40dc8` | same |
| `Sources/Source Measurement/Source.Engine.swift` | `172605b190d1b90877073aefc787301faadbdeec4e9fb5620be30be826ced80a` | same |
| `Sources/Source Measurement/Source.Finding+JSON.Serializable.swift` | `84c3f747f74ff48ef28f6cfe31304be92361d4be26024f70b6e411a629415a2b` | same |
| `Sources/Source Measurement/Source.Finding.swift` | `50bb69d0cfac226590970c7d20839f438155112f681bc2242da69554ec11180a` | same |
| `Sources/Source Measurement/Source.Measurement+JSON.Serializable.swift` | `1a1b9607fe857fa6e87dd6b8afccb2eccbc0b9da5d2c5db4cd4283099553111b` | same |
| `Sources/Source Measurement/Source.Measurement.Verdict+JSON.Serializable.swift` | `c73ba5f08deb3b0ae1655e297d9ba89f12054ebd858e71d0705fbf90e55dd498` | same |
| `Sources/Source Measurement/Source.Measurement.Verdict.swift` | `582b97a15c061c948da1ed0af0da704f8acb280f9c84000df7be9659d5dc0846` | same |
| `Sources/Source Measurement/Source.Measurement.swift` | `83e51956deb1e4494314577795220a898d0b4efb8e656b22db87922b9712d279` | same |
| `Sources/Source Measurement/Source.Reason.swift` | `9b8c6cf6245db4aa6386e6965d26b50050bcbb3591063b9baf130bc096e41222` | same |
| `Sources/Source Measurement/Source.Repair.Capability+JSON.Serializable.swift` | `cdbb0d00bb002936ed6afc56736bd0dabb48aef77ad61b5903f5df645f1ed0bf` | same |
| `Sources/Source Measurement/Source.Repair.Capability.swift` | `1d5fb5d6964a90fb83dcc5aa1466736777c8605719bc0ab72b69711a8b2fbd1b` | same |
| `Sources/Source Measurement/Source.Repair.Evidence+JSON.Serializable.swift` | `0f304bc5f83746ced3778c01e1455e05d056a46b438d773c02aca51519454018` | same |
| `Sources/Source Measurement/Source.Repair.Evidence.Disposition+JSON.Serializable.swift` | `13c79832ec39f7cfe55983fe693691b07083e98a8ab93fdcd2a02c7ed57cba22` | same |
| `Sources/Source Measurement/Source.Repair.Evidence.Disposition.swift` | `ce995a74ee3e7db897bfebfd8761f01cf9454295a14f17969ecb14e70293bf1a` | same |
| `Sources/Source Measurement/Source.Repair.Evidence.Edit+JSON.Serializable.swift` | `0e8e59b0cd1f5f8785f76db271697c3bf4b190f3751817488e46dcfc4ef5a482` | same |
| `Sources/Source Measurement/Source.Repair.Evidence.Edit.swift` | `3d3dafe07356e83c947a1a482838c7991f04a2d02e24c1fd49e5b52418611e31` | same |
| `Sources/Source Measurement/Source.Repair.Evidence.ID.swift` | `c45ada6e276d297832b891f36115876ecc82a0e12aab4b0e105930423ed85636` | same |
| `Sources/Source Measurement/Source.Repair.Evidence.swift` | `440116a3088ba9c496aec03f25820e44e338ce99c0e91cb5cef41278e0aaf3dc` | same |
| `Sources/Source Measurement/Source.Repair.Proposal.Edit.swift` | `8fc406c69176939a4f2840ac8e9cbdd5ac11d3f5a3bf5838950e23dfc7012b66` | same |
| `Sources/Source Measurement/Source.Repair.Proposal.swift` | `afd58007feac4c37c9c1f94785b57d15ff45d864491c638f42dc1fab7fdd2496` | same |
| `Sources/Source Measurement/Source.Repair.Selection.swift` | `738dba51f805f50fbae1731d453cf55c3f6fb70e7d97ccd981f6df70f2a0a00d` | same |
| `Sources/Source Measurement/Source.Repair.swift` | `b2641a43ec087b615c0169656270793eecdf3495f200c346468ca6c304ddd865` | same |
| `Sources/Source Measurement/Source.Rule.Control.Evidence.swift` | `d9b55b8f724f4376411bb42de5b86a0a17de36078551f551778a6d67016cdde7` | same |
| `Sources/Source Measurement/Source.Rule.Control.swift` | `33c675fd9959cfab7216610f1eaef4eeff39ddf8ceb3d12eeacb74ffe58e3bc1` | same |
| `Sources/Source Measurement/Source.Rule.Coverage+JSON.Serializable.swift` | `abd64754b0df4af812ca769a40d45e51cdd9419d4d9f1f28d05e350f1f714fb1` | same |
| `Sources/Source Measurement/Source.Rule.Coverage.swift` | `9a8f601b68ed49866a58a73be02723c3fae26ca29c25822643a9e3f568518fe4` | same |
| `Sources/Source Measurement/Source.Rule.ID.swift` | `82e3e166a9e84138c12b58398b64dd98c1c7eaa7efeadbb2081028b8d5794b72` | same |
| `Sources/Source Measurement/Source.Rule.Observation+JSON.Serializable.swift` | `be33d5f67501393c733ac87da3482e84fa6da8c98b11fd678e8a1a1ddeec3c34` | same |
| `Sources/Source Measurement/Source.Rule.Observation.swift` | `2405320e3bac2808dfbf675d2685ee3c262c7d89f866f21acc4d9fddfb7c20f6` | same |
| `Sources/Source Measurement/Source.Rule.swift` | `edf2f790e7bec6aa6a00184ef1bce3d8ce571af3806ed560164a96d66ef12cc6` | same |
| `Sources/Source Measurement/Source.Subject+JSON.Serializable.swift` | `088e046295423e0fc979f22fb41a832009d93e24f484781e5eabebdaa3270e91` | same |
| `Sources/Source Measurement/Source.Subject.swift` | `6d5ed96377735dae08efe88c924cfa44905e3098db719b16cbab2a68b7e92053` | same |
| `Sources/Source Measurement/exports.swift` | `39d1f6309b9359420254b5fdaef17120cd000d8c6224d84cdf427e7a72ea7ca0` | same |
| `Sources/Source Profile/Source.Engine.Driver.swift` | `b3c84346d8c7e69e95e3cf3be7a4343a59b63529d67dcb4c02bf5d4658cc2a15` | same |
| `Sources/Source Profile/Source.Engine.Process.Result.swift` | `dda76c7b365370d981f2952ee413acaa37b5531d12dbc6e90eb976c67fefa6f0` | same |
| `Sources/Source Profile/Source.Engine.Process.swift` | `a8d30f7e145194bb128efb5dd6aed2310996fe8153f077697dc22b7e3e0d39d3` | same |
| `Sources/Source Profile/Source.Profile.Digest.swift` | `3bbc50d90f5f57ac8c5f9746bdccc912bd5fec1477d2661f4bef2a8b7b46f5e1` | same |
| `Sources/Source Profile/Source.Profile.Engine.swift` | `17118c3d826fc0072fc3409197f6829736a6a36a08086ca524f6253f76a7f1d7` | same |
| `Sources/Source Profile/Source.Profile.Receipt.swift` | `62f776bb9b9768e7c9a265c5ad48d20c170b92f2243f350faeffe82312da4d40` | same |
| `Sources/Source Profile/Source.Profile.swift` | `4a3f2779e784e133be08846677a044773e764c4e1db4201ad2bee5a7b89c23d2` | modified: `382cdd321e13e0cbbf3defe13c8f4114d51389e60fa8b93139a182ff9460caa9` |
| `Sources/Source Profile/exports.swift` | `273babc8da024420053f76a0b194b8f6618298e4bcfd66204a24480249b2e04b` | same |
| `Sources/Source Repair/Source.Repair.FileSystem.swift` | `7510cecda8968a93d96b54841bbd3da870459c2f9cb7e1e2e4591fe3100d6ce1` | same |
| `Sources/Source Repair/Source.Repair.Operation+JSON.Serializable.swift` | `57161a2ef04f6b23cbd2a09bf77510c0baa4fe2018cdbcb1268924c1407d5963` | same |
| `Sources/Source Repair/Source.Repair.Operation.swift` | `75c5ced4dc154b05e6ef15470c99035dd38c0ec4796b1a13acd76767a83560bd` | same |
| `Sources/Source Repair/Source.Repair.Plan.swift` | `79d6257efa4f75c3bf1169c6748c043a9596b76c7503bf2376a950905a8f3cd3` | same |
| `Sources/Source Repair/Source.Repair.Postcondition.swift` | `e2d1b25630790a3d2a5f3798d4a647aa9034ea24d90aa1aaae6101ad5e9ab0f9` | same |
| `Sources/Source Repair/Source.Repair.Refusal.swift` | `8f343308320f648e98e26a7a85cfc6ee276d8fd5d36744637dee8337aab7253c` | same |
| `Sources/Source Repair/Source.Repair.Staged.File.swift` | `4364b74c2eeb0452ad1d4d49a6df4a81f5bfc47bcc81098dbb033305b17910a3` | same |
| `Sources/Source Repair/Source.Repair.Staged.swift` | `e7bcafa033dc102fb28699ad5f129cdba3cc5e34051c60fc48d92d0417b2ea2d` | same |
| `Sources/Source Repair/Source.Repair.Staging.swift` | `c02215f15025dc2bb6582c48a4e7035e0bb1e3c58d6d5ae1ea692caa0293ff22` | modified: `5a76e25e657f522af85af8c31909a622def2abea58e7e0a04e6f60980c873c41` |
| `Sources/Source Repair/Source.Repair.Transaction.Member.swift` | `992cc0f35a7c9a9330c717a8fd885107c38bae4db4734f4131bd369d3cfacd1f` | same |
| `Sources/Source Repair/Source.Repair.Transaction.swift` | `945e90c8e65d64e1a41239e91d2ef7cf112a5f6c715e09b83197ddde6c30d3fd` | modified: `e9e8598854f8db2dbafa2e8929c37b56386e6c4c73988094f4b4c54e58f6bfeb` |
| `Sources/Source Repair/Source.SourceSet+digest.swift` | `5e7228d4cd009cbd68f0e3b6327ac681c08ad9eac1b28532fdb95afb724aa3bf` | modified: `17a642ad361862947cb0f9eed65cf7da3a728a11a5bb6887227c70cbe9ac0880` |
| `Sources/Source Repair/Source.SourceSet.Digest.swift` | `c09de02d774675b83934dbd72ad60a348dd1da742f32271d28350058d032c260` | same |
| `Sources/Source Repair/Source.SourceSet.swift` | `ea6f5c12f3c351e92989b46245dbb962e587318ebb498950861dbf35a64ac1a8` | same |
| `Sources/Source Repair/Source.Subject+binding.swift` | `0321eb8b76fb6ada0d6ac3e76ee126d128d6f3e4ecfcab9b3c252ae1d2072f40` | modified: `9d3e24062c0598a440f12dc004aa3adeca5216e1719a3ef602111394ff8eaa98` |
| `Sources/Source Repair/Source.Subject.Binding.swift` | `a36113760f001f7c93e25df9357b60f4279da8b3f142e1f19946b802015d18df` | same |
| `Sources/Source Repair/exports.swift` | `0149ae7bdd4a09390d9c2d107b71116603cfed57f64627607d5d833a913b2380` | same |
| `Sources/Source Report/Source.Report+human.swift` | `716828bd0415f48199bcbb046c430f2df05b3dd516bebee8a0b9f2e8614f83f0` | same |
| `Sources/Source Report/Source.Report.Commitment.Engine.ControlPolicy.swift` | `511be52116e634ac2feccc59d8e9646583394cabf74236caed43782d02eb9b86` | same |
| `Sources/Source Report/Source.Report.Commitment.Engine.swift` | `29aab512360718b25320cf9094223ce30c5dd22989585c2d2158da8642aef1b4` | same |
| `Sources/Source Report/Source.Report.Commitment.Predicate.swift` | `fa149c205ef973c6c84bb6c6971f341a055b95d6db5e73e91e51d5fafcef7842` | same |
| `Sources/Source Report/Source.Report.Commitment.PredicateRequirement.swift` | `c409d8dcea2c12db97ee363db92f7e8b6edf62df22884edc42be9259426177ea` | same |
| `Sources/Source Report/Source.Report.Commitment.Requirement.swift` | `0e4a20a122731bf3347becf962685619ca3e34eea0735fda1be3ed6c38d38fda` | same |
| `Sources/Source Report/Source.Report.Commitment.Rule.swift` | `3d1835daf8d11709dcc32e4bd1e75b1c7d271830a4da94deb2e4b0776423123e` | same |
| `Sources/Source Report/Source.Report.Commitment.swift` | `87315c6a2b23ab16d7c578d6917f2c1e676abadb72f237618cf569e20c20cf86` | same |
| `Sources/Source Report/Source.Report.Complete.Error.swift` | `80dc785f90c8b7c267fbfa59a319b672bfcaa15424e76ba2ba702a23c0bda97b` | same |
| `Sources/Source Report/Source.Report.Complete.swift` | `c0ca5e23c6b3b58e9760e17bd9c2dd1879beada7f0072a7799febdabcc70de74` | same |
| `Sources/Source Report/Source.Report.Scope.swift` | `f3b07aa1da47ffd0b709a5cf06c1b83ea881fb14c06787e3112bf730b36a929f` | same |
| `Sources/Source Report/Source.Report.Status.swift` | `d32b22519f2afc999d71aad9762d0b652c8220732b3e4636460b460be75ce65d` | same |
| `Sources/Source Report/Source.Report.swift` | `0e76ef18f6af5cdfc1c72f5e799009e6b6fb54595cbf22e1cc8e1713b2eefc77` | same |
| `Sources/Source Report/exports.swift` | `555c635e04894adc5f5b86c92264140fc5b4926e3a3a7ce12b6bd50e5854abb1` | same |
| `Sources/Source Swift Format/Source.Engine.Driver+swiftFormat.swift` | `251ee7475231807094b06157e6f55450ae6e48fbf5fcdccc11363a1de89a12dc` | same |
| `Sources/Source Swift Format/Source.Measurement+swiftFormat.swift` | `e85bc629435b72f051001b06285451b16907fb9c5becb2cfa8f28254c044885d` | same |
| `Sources/Source Swift Format/exports.swift` | `8e918706d0b1f3b4281080eee4383e9d2fd913fe52d2671d9cfa9095bbfcc147` | same |
| `Sources/Source SwiftLint/Source.Engine.Driver+swiftLint.swift` | `82b70cc6146fc3ef72111a5c868f75d4d479096afb5ff00db8b10e62a37b9de5` | same |
| `Sources/Source SwiftLint/Source.Measurement+swiftLint.swift` | `267b09c878b8e4c4dab8b0bdceb93957de6241ef6bf95a5d1599cdc64dd3fdca` | same |
| `Sources/Source SwiftLint/exports.swift` | `8e918706d0b1f3b4281080eee4383e9d2fd913fe52d2671d9cfa9095bbfcc147` | same |
