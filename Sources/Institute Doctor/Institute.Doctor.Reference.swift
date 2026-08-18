public import Institute_Development
public import Institute_Inventory
public import Institute_Lint
public import Institute_Model
public import Institute_Pages

extension Institute.Doctor {
    /// The generated workspace document against the rendering required by
    /// the resolved selection.
    public struct Reference: Equatable, Sendable {
        public let expected: Swift.String
        public let actual: Swift.String?

        public init(expected: Swift.String, actual: Swift.String?) {
            self.expected = expected
            self.actual = actual
        }
    }
}

extension Institute.Doctor {
    /// `institute.xcworkspace` matches the resolved selection.
    public static let reference = Check<Reference>(
        name: "workspace-reference",
        scope: .contributor,
        controls: .init(
            positive: .init(expected: "expected", actual: "different"),
            negative: .init(expected: "expected", actual: "expected")
        )
    ) { reference in
        guard let actual = reference.actual else {
            return [
                .init(
                    severity: .error,
                    message:
                        "institute.xcworkspace is missing; it is generated rather than committed — "
                        + "run `institute sync` to write it from Selection.json"
                )
            ]
        }
        guard actual != reference.expected else { return [] }
        return [
            .init(
                severity: .error,
                message:
                    "institute.xcworkspace does not match the resolved selection; "
                    + "run `institute sync` to regenerate it"
            )
        ]
    }

    func reference() -> Outcome {
        Self.reference.run(
            population: [
                .init(
                    expected: Institute.Xcode.render(selection.repositories),
                    actual: Institute.Xcode.contents(at: root.checkout)
                )
            ],
            inventory: 1
        )
    }
}
