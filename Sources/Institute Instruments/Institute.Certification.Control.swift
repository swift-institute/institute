public import Institute_Model
public import JSON

extension Institute.Certification {
    /// The exact control identities that judged a certificate: which
    /// certifier, which toolchain, which CI policy, and which runtime
    /// receipts.
    ///
    /// Runtime/executable-input determinism is owned by
    /// `swift-institute/.github#43`; its receipts are *referenced* here by
    /// digest, never duplicated. A certificate whose control inputs later
    /// move is superseded exactly as when a member revision moves —
    /// control-input promotion follows `swift-institute/.github#627`.
    public struct Control: Equatable, Sendable, JSON.Serializable {
        /// The exact revision of `swift-institute/institute` whose
        /// certifier code produced the certificate.
        public let certifier: Revision

        /// The observed toolchain identity — `swift --version` output
        /// class, not a declared floor.
        public let toolchain: Swift.String

        /// The exact CI policy identity — the `swift-institute/.github`
        /// revision whose workflow/action policy governed execution, when
        /// hosted execution participated; absent for purely local
        /// evaluation.
        public let policy: Revision?

        /// Digests of the deterministic runtime receipts
        /// (`swift-institute/.github#43`) for the hosted runs that
        /// produced evidence, when hosted execution participated.
        public let runtimeReceipts: [Swift.String]

        public init(
            certifier: Revision,
            toolchain: Swift.String,
            policy: Revision?,
            runtimeReceipts: [Swift.String]
        ) {
            self.certifier = certifier
            self.toolchain = toolchain
            self.policy = policy
            self.runtimeReceipts = runtimeReceipts.sorted()
        }
    }
}

extension Institute.Certification.Control {
    public static func serialize(_ value: Self) -> JSON {
        [
            "certifier": value.certifier.json,
            "toolchain": value.toolchain.json,
            "policy": value.policy.json,
            "runtimeReceipts": value.runtimeReceipts.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard let certifier = object["certifier"] else { throw .missingKey("certifier") }
        guard let toolchain = object["toolchain"] else { throw .missingKey("toolchain") }
        guard let runtimeReceipts = object["runtimeReceipts"] else {
            throw .missingKey("runtimeReceipts")
        }
        return try Self(
            certifier: Institute.Certification.Revision(json: certifier),
            toolchain: Swift.String(json: toolchain),
            policy: Institute.Certification.Revision?(json: object["policy"] ?? .null),
            runtimeReceipts: [Swift.String](json: runtimeReceipts)
        )
    }
}
