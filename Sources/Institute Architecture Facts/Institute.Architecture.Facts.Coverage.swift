public import Institute_Architecture_Model
public import Institute_Model

extension Institute.Architecture.Facts {
    /// The manifest measurement state for the inventory population.
    ///
    /// A required owner is measured only when its manifest was read. Missing
    /// manifests stay explicit here; they never become empty package facts.
    public struct Coverage: Sendable, Equatable {
        public let required: [Institute.Architecture.Owner]
        public let measured: [Institute.Architecture.Owner]

        public init(
            required: [Institute.Architecture.Owner],
            measured: [Institute.Architecture.Owner]
        ) {
            self.required = required.sorted()
            self.measured = measured.sorted()
        }
    }
}

extension Institute.Architecture.Facts.Coverage {
    /// Required owners whose manifests were not measured.
    public var unmeasured: [Institute.Architecture.Owner] {
        let measured = Swift.Set(measured)
        return required.filter { !measured.contains($0) }
    }

    /// Whether the full required inventory population was measured.
    public var complete: Swift.Bool {
        unmeasured.isEmpty
    }
}
