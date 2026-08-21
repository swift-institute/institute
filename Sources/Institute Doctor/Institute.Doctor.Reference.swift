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
        public let expectedMembership: Swift.String
        public let actualMembership: Swift.String?

        public init(
            expected: Swift.String,
            actual: Swift.String?,
            expectedMembership: Swift.String,
            actualMembership: Swift.String?
        ) {
            self.expected = expected
            self.actual = actual
            self.expectedMembership = expectedMembership
            self.actualMembership = actualMembership
        }
    }
}

extension Institute.Doctor {
    /// The exact interim workspace matches the resolved selection.
    public static let reference = Check<Reference>(
        name: "workspace-reference",
        scope: .contributor,
        controls: .init(
            positive: .init(
                expected: "expected",
                actual: "different",
                expectedMembership: "members",
                actualMembership: "members"
            ),
            negative: .init(
                expected: "expected",
                actual: "expected",
                expectedMembership: "members",
                actualMembership: "members"
            )
        )
    ) { reference in
        guard let actual = reference.actual else {
            return [
                .init(
                    severity: .error,
                    message:
                        "institute interim.xcworkspace is missing; it is generated rather than committed — "
                        + "run `institute sync` to write it from Selection.json"
                )
            ]
        }
        guard reference.actualMembership == reference.expectedMembership else {
            return [
                .init(
                    severity: .error,
                    message:
                        "institute interim.xcworkspace membership roles are missing or stale; "
                        + "run `institute sync` to regenerate it"
                )
            ]
        }
        guard actual == reference.expected else {
            return [
                .init(
                    severity: .error,
                    message:
                        "institute interim.xcworkspace does not match the resolved selection; "
                        + "run `institute sync` to regenerate it"
                )
            ]
        }
        return []
    }

    func reference() -> Outcome {
        let expected: Swift.String
        let expectedMembership: Swift.String
        do {
            let specification = try Institute.Xcode.specification(selection.repositories)
            expected = try Institute.Xcode.render(specification)
            expectedMembership = specification.jsonString(sortKeys: true) + "\n"
        } catch {
            expected = "workspace specification error: \(error)"
            expectedMembership = expected
        }
        Self.reference.run(
            population: [
                .init(
                    expected: expected,
                    actual: Institute.Xcode.contents(at: root.checkout),
                    expectedMembership: expectedMembership,
                    actualMembership: Institute.Xcode.specificationContents(at: root.checkout)
                )
            ],
            inventory: 1
        )
    }
}
