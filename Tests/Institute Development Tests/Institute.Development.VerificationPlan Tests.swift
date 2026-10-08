import Dispatch
import File_System
import Synchronization
import Testing

@testable import Institute_Development
@testable import Institute_Model

extension Institute.Development.VerificationPlan {
    /// Serialized: the plan enforces one running verification plan per
    /// process, so concurrent test cases would refuse each other.
    @Suite(.serialized)
    struct Test {
        @Suite(.serialized) struct Transaction {}
        @Suite(.serialized) struct `Edge Case` {}
    }
}

extension Institute.Development.VerificationPlan.Test {
    /// A throwaway workspace: two consumers declaring URL dependencies, the
    /// dependencies present at their org-layout checkouts, a source map
    /// covering the dependencies plus one forward-closure repository no
    /// consumer declares, and a sentinel `Package.resolved` that must never
    /// change.
    struct Fixture {
        static let resolvedSentinel = "{\"originHash\" : \"sentinel — never touched\"}\n"

        let base: Swift.String
        let root: Swift.String
        let resolved: Swift.String
        let plan: Institute.Development.VerificationPlan

        init() throws {
            let temporary = DevelopmentFixtureFiles.temporaryPath(
                resolvingSymlinks: false,
                DevelopmentFixtureFiles.uniqueName()
            )
            let checkout = DevelopmentFixtureFiles.join(temporary, "Institute")
            try DevelopmentFixtureFiles.createDirectory(checkout)
            let workspaceRoot = try Institute.Root(
                checkout: File.Directory(validating: checkout)
            )
            base = DevelopmentFixtureFiles.directoryPath(workspaceRoot.hierarchy.description)
            root = DevelopmentFixtureFiles.directoryPath(workspaceRoot.checkout.description)
            resolved = DevelopmentFixtureFiles.join(
                base,
                "swift-foundations/example/consumer/Package.resolved"
            )

            for directory in [
                "swift-foundations/example/consumer",
                "swift-foundations/example/consumer-b",
                "swift-standards/example/swift-dep-a",
                "swift-standards/example/swift-dep-b",
                "swift-standards/example/swift-closure",
            ] {
                try DevelopmentFixtureFiles.createDirectory(DevelopmentFixtureFiles.join(base, directory))
            }
            try DevelopmentFixtureFiles.write(
                Self.consumerSource,
                to: DevelopmentFixtureFiles.join(base, "swift-foundations/example/consumer/Package.swift")
            )
            try DevelopmentFixtureFiles.write(
                Self.consumerBSource,
                to: DevelopmentFixtureFiles.join(base, "swift-foundations/example/consumer-b/Package.swift")
            )
            try DevelopmentFixtureFiles.write(Self.resolvedSentinel, to: resolved)

            let composition = Institute.Composition(
                root: workspaceRoot,
                configuration: .init(
                    version: 1,
                    scope: "example",
                    swift: "6.3.3",
                    xcode: "26.6",
                    repositories: [
                        .init(
                            name: "consumer",
                            url: "https://github.com/example/consumer.git",
                            organization: "example",
                            layer: .foundations
                        ),
                        .init(
                            name: "consumer-b",
                            url: "https://github.com/example/consumer-b.git",
                            organization: "example",
                            layer: .foundations
                        ),
                        .init(
                            name: "swift-dep-a",
                            url: "https://github.com/example/swift-dep-a.git",
                            organization: "example",
                            layer: .standards
                        ),
                        .init(
                            name: "swift-dep-b",
                            url: "https://github.com/example/swift-dep-b.git",
                            organization: "example",
                            layer: .standards
                        ),
                        .init(
                            name: "swift-closure",
                            url: "https://github.com/example/swift-closure.git",
                            organization: "example",
                            layer: .standards
                        ),
                    ]
                )
            )
            plan = Institute.Development.VerificationPlan(
                composition: composition,
                assignments: [
                    .init(
                        reference: "swift-dep-a",
                        url: "https://github.com/example/swift-dep-a.git",
                        path: "\(workspaceRoot.hierarchy)/swift-standards/example/swift-dep-a"
                    ),
                    .init(
                        reference: "swift-dep-b",
                        url: "https://github.com/example/swift-dep-b.git",
                        path: "\(workspaceRoot.hierarchy)/swift-standards/example/swift-dep-b"
                    ),
                    // Forward-closure entry: a redirect target no consumer
                    // declares — never an automatic verification subject.
                    .init(
                        reference: "swift-closure",
                        url: "https://github.com/example/swift-closure.git",
                        path: "\(workspaceRoot.hierarchy)/swift-standards/example/swift-closure"
                    ),
                ]
            )
        }

        // Stays in the type body deliberately: `Fixture` is nested inside a
        // `@Suite` type, and [API-ERR-001]'s `@Suite`-member exemption for
        // bare `throws` does not follow a member out into an extension.
        // `Swift.String(contentsOf:encoding:)` throws untyped, so there is
        // no `E` to name.
        func read(_ consumer: Swift.String) throws -> Swift.String {
            try DevelopmentFixtureFiles.readStrictUTF8(
                DevelopmentFixtureFiles.join(base, "swift-foundations/example/\(consumer)/Package.swift")
            )
        }

        func write(_ source: Swift.String, consumer: Swift.String) throws {
            try DevelopmentFixtureFiles.write(
                source,
                to: DevelopmentFixtureFiles.join(base, "swift-foundations/example/\(consumer)/Package.swift")
            )
        }

        func readResolved() throws -> Swift.String {
            try DevelopmentFixtureFiles.readStrictUTF8(resolved)
        }
    }
}

extension Institute.Development.VerificationPlan.Test.Fixture {
    static let consumerSource = """
        // swift-tools-version: 6.3.3
        import PackageDescription

        let package = Package(
            name: "consumer",
            dependencies: [
                .package(url: "https://github.com/example/swift-dep-a.git", branch: "main"),
                .package(url: "https://github.com/example/swift-dep-b.git", branch: "main"),
            ],
            targets: []
        )

        """

    static let consumerBSource = """
        // swift-tools-version: 6.3.3
        import PackageDescription

        let package = Package(
            name: "consumer-b",
            dependencies: [
                .package(url: "https://github.com/example/swift-dep-a.git", branch: "main")
            ],
            targets: []
        )

        """

    func remove() { try? DevelopmentFixtureFiles.remove(base) }
}

extension Institute.Development.VerificationPlan.Test.Transaction {
    @Test
    func `two local overrides are simultaneously active for one consumer`() throws {
        let fixture = try Institute.Development.VerificationPlan.Test.Fixture()
        defer { fixture.remove() }
        let original = try fixture.read("consumer")

        var observed = [Swift.String]()
        let results = try fixture.plan.run(seeds: ["consumer"]) {
            (_: Swift.String) throws(Institute.Error) in
            observed.append(try fixture.readDuringVerification())
            return .passed
        }

        #expect(results.count == 1)
        #expect(results[0].seed == "consumer")
        #expect(results[0].verification == .passed)
        #expect(results[0].composed == ["swift-dep-a", "swift-dep-b"])

        // While the owner ran, BOTH overrides were applied at once.
        let applied = try #require(observed.first)
        #expect(applied.contains("/swift-standards/example/swift-dep-a\")"))
        #expect(applied.contains("/swift-standards/example/swift-dep-b\")"))
        #expect(!applied.contains("https://github.com/example/swift-dep-a.git"))
        #expect(!applied.contains("https://github.com/example/swift-dep-b.git"))

        // And afterwards the preimage is back, byte for byte.
        #expect(try fixture.read("consumer") == original)
        let sentinel = Institute.Development.VerificationPlan.Test.Fixture.resolvedSentinel
        #expect(try fixture.readResolved() == sentinel)
    }

    @Test
    func `an injected failure after the first mutation restores every preimage`() throws {
        let fixture = try Institute.Development.VerificationPlan.Test.Fixture()
        defer { fixture.remove() }
        let original = try fixture.read("consumer")

        #expect(throws: Institute.Error.self) {
            try fixture.plan.run(seeds: ["consumer"]) {
                (_: Swift.String) throws(Institute.Error) in
                // The manifest is mutated at this point; fail after it.
                throw Institute.Error.composition("injected verification owner failure")
            }
        }

        #expect(try fixture.read("consumer") == original)
        let sentinel = Institute.Development.VerificationPlan.Test.Fixture.resolvedSentinel
        #expect(try fixture.readResolved() == sentinel)
        #expect(DevelopmentFixtureFiles.exists(fixture.resolved))
    }

    @Test
    func `cancellation restores every preimage`() async throws {
        let fixture = try Institute.Development.VerificationPlan.Test.Fixture()
        defer { fixture.remove() }
        let original = try fixture.read("consumer")

        let started = Mutex<Swift.Bool>(false)
        let proceed = DispatchSemaphore(value: 0)
        let plan = fixture.plan
        let task = Task.detached {
            try plan.run(seeds: ["consumer"]) { _ in
                started.withLock { flag in flag = true }
                proceed.wait()
                return .passed
            }
        }
        while !started.withLock({ flag in flag }) {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        task.cancel()
        proceed.signal()

        await #expect(throws: Institute.Error.self) {
            _ = try await task.value
        }
        #expect(try fixture.read("consumer") == original)
        let sentinel = Institute.Development.VerificationPlan.Test.Fixture.resolvedSentinel
        #expect(try fixture.readResolved() == sentinel)
    }

    @Test
    func `verification order equals deterministic inventory-reference order`() throws {
        let fixture = try Institute.Development.VerificationPlan.Test.Fixture()
        defer { fixture.remove() }

        var order = [Swift.String]()
        let results = try fixture.plan.run(seeds: ["consumer-b", "consumer"]) { seed in
            order.append(seed)
            return .passed
        }

        #expect(order == ["consumer", "consumer-b"])
        #expect(results.map(\.seed) == ["consumer", "consumer-b"])
    }

    @Test
    func `forward-closure dependencies are not automatic verification subjects`() throws {
        let fixture = try Institute.Development.VerificationPlan.Test.Fixture()
        defer { fixture.remove() }

        var invocations = 0
        let results = try fixture.plan.run(seeds: ["consumer"]) { _ in
            invocations += 1
            return .passed
        }

        // One seed, one verification; the closure entry contributed no
        // subject and no rewrite (no consumer declares it by URL).
        #expect(invocations == 1)
        #expect(results.count == 1)
        #expect(!results[0].composed.contains("swift-closure"))
    }
}

extension Institute.Development.VerificationPlan.Test.Fixture {
    /// Reads the consumer manifest while a verification owner runs.
    func readDuringVerification() throws(Institute.Error) -> Swift.String {
        do {
            return try DevelopmentFixtureFiles.readStrictUTF8(
                DevelopmentFixtureFiles.join(base, "swift-foundations/example/consumer/Package.swift")
            )
        } catch {
            throw .composition("cannot read the composed manifest: \(error)")
        }
    }
}

extension Institute.Development.VerificationPlan.Test.`Edge Case` {
    @Test
    func `an active pairwise composition refuses before any mutation`() throws {
        let fixture = try Institute.Development.VerificationPlan.Test.Fixture()
        defer { fixture.remove() }
        let original = try fixture.read("consumer")

        let record = Institute.Composition.Record(
            consumer: "consumer",
            dependency: "swift-dep-a",
            declared: ".package(url: \"https://github.com/example/swift-dep-a.git\", "
                + "branch: \"main\")",
            planned: ".package(path: \"/somewhere/swift-dep-a\")"
        )
        try Institute.Composition.State(records: [record]).save(
            at: File.Directory(validating: fixture.root)
        )

        var invocations = 0
        #expect(throws: Institute.Error.self) {
            try fixture.plan.run(seeds: ["consumer"]) { _ in
                invocations += 1
                return .passed
            }
        }

        #expect(invocations == 0)
        #expect(try fixture.read("consumer") == original)
    }

    @Test
    func `an unrecorded composed clause refuses before any mutation`() throws {
        let fixture = try Institute.Development.VerificationPlan.Test.Fixture()
        defer { fixture.remove() }

        // Hand-compose the manifest without a ledger record: the planned
        // clause is present but nothing records how to reverse it.
        let assignment = try #require(
            fixture.plan.assignments.first { $0.reference == "swift-dep-a" }
        )
        let planned = ".package(path: \"\(assignment.path)\")"
        let clean = Institute.Development.VerificationPlan.Test.Fixture.consumerSource
        let dirty = DevelopmentFixtureFiles.replacingAll(
            ".package(url: \"https://github.com/example/swift-dep-a.git\", branch: \"main\"),",
            with: planned + ",",
            in: clean
        )
        try fixture.write(dirty, consumer: "consumer")

        var invocations = 0
        #expect(throws: Institute.Error.self) {
            try fixture.plan.run(seeds: ["consumer"]) { _ in
                invocations += 1
                return .passed
            }
        }

        #expect(invocations == 0)
        #expect(try fixture.read("consumer") == dirty)
    }

    @Test
    func `Package_resolved is never modified, edited or deleted`() throws {
        let fixture = try Institute.Development.VerificationPlan.Test.Fixture()
        defer { fixture.remove() }

        _ = try fixture.plan.run(seeds: ["consumer", "consumer-b"]) { _ in .passed }
        #expect(throws: Institute.Error.self) {
            try fixture.plan.run(seeds: ["consumer"]) {
                (_: Swift.String) throws(Institute.Error) in
                throw Institute.Error.composition("injected failure")
            }
        }

        #expect(DevelopmentFixtureFiles.exists(fixture.resolved))
        let sentinel = Institute.Development.VerificationPlan.Test.Fixture.resolvedSentinel
        #expect(try fixture.readResolved() == sentinel)
    }

    @Test
    func `a second concurrent plan is refused: one verification at a time`() async throws {
        let fixture = try Institute.Development.VerificationPlan.Test.Fixture()
        defer { fixture.remove() }

        let started = Mutex<Swift.Bool>(false)
        let proceed = DispatchSemaphore(value: 0)
        let plan = fixture.plan
        let task = Task.detached {
            try plan.run(seeds: ["consumer"]) { _ in
                started.withLock { flag in flag = true }
                proceed.wait()
                return .passed
            }
        }
        while !started.withLock({ flag in flag }) {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        defer { proceed.signal() }

        #expect(throws: Institute.Error.self) {
            try plan.run(seeds: ["consumer-b"]) { _ in .passed }
        }

        proceed.signal()
        _ = try await task.value
    }

    @Test
    func `the pair API delegates through a one-entry source map`() throws {
        let fixture = try Institute.Development.VerificationPlan.Test.Fixture()
        defer { fixture.remove() }
        let source = try fixture.read("consumer")

        // The same transaction the pair API constructs: one entry.
        let transaction = try Institute.Development.VerificationPlan.Transaction.begin(
            consumer: "consumer",
            manifest: File(
                try File.Path(
                    "\(fixture.base)/swift-foundations/example/consumer/Package.swift"
                )
            ),
            source: source,
            assignments: [
                .init(
                    reference: "swift-dep-a",
                    url: "https://github.com/example/swift-dep-a.git",
                    path: "\(fixture.base)/swift-standards/example/swift-dep-a"
                )
            ],
            ledger: .init()
        )

        #expect(transaction.rewrites.count == 1)
        #expect(transaction.preimage == source)
        #expect(
            transaction.rewrites[0].declared
                == ".package(url: \"https://github.com/example/swift-dep-a.git\", branch: \"main\")"
        )
        // Only the mapped clause changed; the other declaration is intact.
        #expect(transaction.applied.contains("https://github.com/example/swift-dep-b.git"))
        #expect(!transaction.applied.contains("https://github.com/example/swift-dep-a.git"))
    }
}
