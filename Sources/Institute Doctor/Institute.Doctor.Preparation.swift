internal import File_System
internal import Institute_Development
public import Institute_Model
internal import Institute_Source
internal import Source_Measurement

extension Institute.Doctor {
    /// One assertion about the checkout's source preparation.
    public enum Preparation: Equatable, Sendable {
        /// `institute source prepare` has written a receipt for the
        /// workspace. Neither `source measure` nor `source repair` can run
        /// without one.
        case prepared(Swift.Bool)

        /// The receipt still backs a measurement under the current source
        /// policy: `nil` when it does, otherwise the staleness reason
        /// measurement itself would refuse with.
        case current(stale: Swift.String?)
    }
}

extension Institute.Doctor {
    /// The checkout's source tooling is prepared, and the preparation is
    /// the one the current source policy pins.
    ///
    /// Parity with CI is by construction: CI's source leg acquires the
    /// same policy-pinned engines, verified by digest, and renders the same
    /// profiles. What a checkout can get wrong is not having prepared, or
    /// holding a preparation an engine or policy change has since
    /// superseded. Both are warnings, not errors: measurement refuses a
    /// stale preparation as unmeasured, so neither can produce an answer
    /// that disagrees with CI while looking authoritative.
    public static let preparation = Check<Preparation>(
        name: "source-preparation",
        scope: .contributor,
        controls: .init(
            positive: .prepared(false),
            negative: .prepared(true)
        )
    ) { subject in
        switch subject {
        case .prepared(let prepared):
            guard !prepared else { return [] }
            return [
                .init(
                    severity: .warning,
                    message: "source tooling is not prepared; run `institute source prepare "
                        + "--workspace-path '\(Institute.Xcode.bundleName)'` from the checkout. "
                        + "Neither `institute source measure` nor `institute source repair` can run without it."
                )
            ]

        case .current(let stale):
            guard let stale else { return [] }
            return [
                .init(
                    severity: .warning,
                    message: "source preparation is stale (\(stale)); rerun `institute source prepare` "
                        + "before measuring, or every measurement is refused as unmeasured"
                )
            ]
        }
    }

    func preparation() -> Outcome {
        let workspace = Institute.Xcode.bundle(at: root.checkout).description
        let receipt: File
        do throws(Institute.Error) {
            receipt = try Institute.Source.Application.artifactDirectory(workspace: workspace)[
                file: "receipt.json"
            ]
        } catch {
            return Self.preparation.unmeasured(reason: "cannot locate the source preparation: \(error)")
        }
        guard receipt.stat.isFile else {
            return Self.preparation.run(population: [.prepared(false)], inventory: 2)
        }
        let preparation: Institute.Source.Preparation
        do throws(Institute.Error) {
            preparation = try Institute.Source.Preparation.read(workspace: workspace)
        } catch {
            return Self.preparation.unmeasured(reason: "cannot read the source preparation: \(error)")
        }
        let stale = Institute.Source.Application.staleness(of: preparation).map {
            "\($0.code): \($0.detail)"
        }
        return Self.preparation.run(
            population: [.prepared(true), .current(stale: stale)],
            inventory: 2
        )
    }
}
