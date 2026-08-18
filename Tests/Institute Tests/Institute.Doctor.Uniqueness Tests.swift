import Testing

@testable import Institute_Conversion
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Doctor
@testable import Institute_Instruments
@testable import Institute_Inventory
@testable import Institute_Lint
@testable import Institute_Model
@testable import Institute_Pages

// MARK: - Fleet-wide name uniqueness

extension Institute.Doctor.Test.Unit {
    private static func declaration(
        repository: Swift.String,
        products: [Swift.String] = [],
        targets: [Swift.String] = []
    ) -> Institute.Doctor.Uniqueness.Declaration {
        .init(repository: repository, products: products, targets: targets)
    }

    @Test
    func `a fleet whose names are unique measures ok`() {
        let population = Institute.Doctor.Uniqueness.population(of: [
            Self.declaration(repository: "swift-a", products: ["A"], targets: ["A", "A CLI"]),
            Self.declaration(repository: "swift-b", products: ["B"], targets: ["B"]),
        ])
        let outcome = Institute.Doctor.uniqueness.run(population: population, inventory: 2)

        #expect(outcome.result == .ok(population: 5))
        #expect(outcome.findings.isEmpty)
    }

    @Test
    func `a target name declared by two repositories is an error naming both owners`() {
        let population = Institute.Doctor.Uniqueness.population(of: [
            Self.declaration(repository: "swift-a", targets: ["Shared"]),
            Self.declaration(repository: "swift-b", targets: ["Shared"]),
        ])
        let outcome = Institute.Doctor.uniqueness.run(population: population, inventory: 2)

        #expect(outcome.result == .finding(severity: .error, population: 1))
        #expect(
            outcome.findings
                == [
                    .init(
                        severity: .error,
                        message: "target Shared is declared by swift-a, swift-b"
                    )
                ]
        )
    }

    @Test
    func `a library product name declared by two repositories is an error naming both owners`() {
        let population = Institute.Doctor.Uniqueness.population(of: [
            Self.declaration(repository: "swift-b", products: ["Shared"]),
            Self.declaration(repository: "swift-a", products: ["Shared"]),
        ])
        let outcome = Institute.Doctor.uniqueness.run(population: population, inventory: 2)

        #expect(outcome.result == .finding(severity: .error, population: 1))
        // Owners are sorted, never declaration-ordered.
        #expect(
            outcome.findings
                == [
                    .init(
                        severity: .error,
                        message: "product Shared is declared by swift-a, swift-b"
                    )
                ]
        )
    }
}

extension Institute.Doctor.Test.`Edge Case` {
    @Test
    func `a within-manifest duplicate declaration is one ownership, never a collision`() {
        // The same target declared twice in one manifest — lawful under
        // platform conditions — collapses to one owner.
        let population = Institute.Doctor.Uniqueness.population(of: [
            .init(repository: "swift-a", products: [], targets: ["Conditional", "Conditional"])
        ])
        let outcome = Institute.Doctor.uniqueness.run(population: population, inventory: 1)

        #expect(population == [.init(namespace: .target, name: "Conditional", owners: ["swift-a"])])
        #expect(outcome.result == .ok(population: 1))
    }

    @Test
    func `a product and a target sharing a name across repositories are separate namespaces`() {
        let population = Institute.Doctor.Uniqueness.population(of: [
            .init(repository: "swift-a", products: ["Shared"], targets: []),
            .init(repository: "swift-b", products: [], targets: ["Shared"]),
        ])
        let outcome = Institute.Doctor.uniqueness.run(population: population, inventory: 2)

        #expect(outcome.result == .ok(population: 2))
    }

    @Test
    func `three owners of one name are all named in one finding`() {
        let population = Institute.Doctor.Uniqueness.population(of: [
            .init(repository: "swift-c", products: [], targets: ["Shared"]),
            .init(repository: "swift-a", products: [], targets: ["Shared"]),
            .init(repository: "swift-b", products: [], targets: ["Shared"]),
        ])
        let outcome = Institute.Doctor.uniqueness.run(population: population, inventory: 3)

        #expect(
            outcome.findings.map(\.message)
                == ["target Shared is declared by swift-a, swift-b, swift-c"]
        )
    }

    @Test
    func `the population is deterministic: products before targets, names sorted`() {
        let population = Institute.Doctor.Uniqueness.population(of: [
            .init(repository: "swift-a", products: ["Z", "A"], targets: ["M"]),
            .init(repository: "swift-b", products: [], targets: ["B"]),
        ])

        #expect(
            population
                == [
                    .init(namespace: .product, name: "A", owners: ["swift-a"]),
                    .init(namespace: .product, name: "Z", owners: ["swift-a"]),
                    .init(namespace: .target, name: "B", owners: ["swift-b"]),
                    .init(namespace: .target, name: "M", owners: ["swift-a"]),
                ]
        )
    }

    @Test
    func `an empty fleet against an empty inventory is ok at population zero`() {
        let outcome = Institute.Doctor.uniqueness.run(
            population: Institute.Doctor.Uniqueness.population(of: []),
            inventory: 0
        )

        #expect(outcome.result == .ok(population: 0))
    }

    @Test
    func `an empty population against a non-empty inventory is unmeasured, never ok`() {
        let outcome = Institute.Doctor.uniqueness.run(population: [], inventory: 462)

        #expect(
            outcome.result
                == .unmeasured(reason: "empty population against an inventory of 462")
        )
    }
}
