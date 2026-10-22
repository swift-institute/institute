import Testing

@testable import Institute_Doctor
@testable import Institute_Model

extension Institute.Doctor.Test.Unit {
    @Test
    func `a third party URL claiming an Institute package identity is an error`() {
        let outcome = Institute.Doctor.dependency.run(
            population: [
                .init(
                    repository: "consumer",
                    line: 12,
                    url: "https://github.com/vendor/swift-dependencies.git",
                    institute: [
                        "https://github.com/swift-compositions/swift-dependencies.git"
                    ]
                )
            ],
            inventory: 1
        )

        #expect(outcome.result == .finding(severity: .error, population: 1))
        #expect(outcome.findings[0].message.contains("consumer/Package.swift:12"))
        #expect(outcome.findings[0].message.contains("keep the Institute package name"))
    }

    @Test
    func `the Institute URL for its own package identity passes`() {
        let url = "https://github.com/swift-compositions/swift-dependencies.git"
        let outcome = Institute.Doctor.dependency.run(
            population: [
                .init(repository: "consumer", line: 12, url: url, institute: [url])
            ],
            inventory: 1
        )

        #expect(outcome.result == .ok(population: 1))
        #expect(outcome.findings.isEmpty)
    }

    @Test
    func `manifest scan preserves URL slashes and excludes commented declarations`() throws {
        let source = #"""
            let package = Package(
                dependencies: [
                    // .package(url: "https://github.com/commented/swift-other.git", branch: "main"),
                    .package(url: "https://github.com/vendor/swift-dependencies.git", branch: "main"),
                ]
            )
            """#

        let dependencies = try Institute.Doctor.dependencies(
            repository: "consumer",
            source: source,
            institute: [
                "swift-dependencies": [
                    "https://github.com/swift-compositions/swift-dependencies.git"
                ],
                "swift-other": ["https://github.com/swift-atoms/swift-other.git"],
            ]
        )

        #expect(dependencies.count == 1)
        #expect(dependencies[0].url == "https://github.com/vendor/swift-dependencies.git")
        #expect(
            dependencies[0].institute
                == ["https://github.com/swift-compositions/swift-dependencies.git"]
        )
    }
}
