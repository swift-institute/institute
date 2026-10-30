import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Idiom

extension Lint.Rule {
    @Suite
    struct `existential parameter Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`existential parameter Tests` {
    static func findings(
        _ source: Swift::String,
        file: Swift::String = "Sources/Fixture/Fixture.swift"
    ) -> [Diagnostic.Record] {
        Lint.Rule.`existential parameter`
            .observe(Lint.Source.parsed(from: source, file: file), .warning)
            .findings
    }
}

extension Lint.Rule.`existential parameter Tests`.Unit {
    @Test
    func `existential parameters are flagged`() {
        let findings = Lint.Rule.`existential parameter Tests`.findings(
            """
            func render(_ view: any View, into sink: [any Sink], fallback: (any View)?) {}
            init(source: any Source) {}
            subscript(key: any Hashable) -> Int { 0 }
            """
        )
        #expect(findings.count == 5)
        #expect(findings[0].message.hasPrefix("[existential parameter] [SOURCE-EXISTENTIAL-PARAMETER]:"))
    }

    @Test
    func `generic and opaque parameters are clean`() {
        let findings = Lint.Rule.`existential parameter Tests`.findings(
            "func render<V: View>(_ view: V, other: some View) {}"
        )
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`existential parameter Tests`.`Edge Case` {
    @Test
    func `any Error is admitted`() {
        let findings = Lint.Rule.`existential parameter Tests`.findings(
            "func report(_ error: any Error, other: any Swift.Error) {}"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `closure parameter types are left to the closure`() {
        let findings = Lint.Rule.`existential parameter Tests`.findings(
            "func each(_ body: (any View) -> Void) {}"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `tests are out of scope`() {
        let findings = Lint.Rule.`existential parameter Tests`.findings(
            "func render(_ view: any View) {}",
            file: "Tests/Fixture Tests/Fixture Tests.swift"
        )
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`existential parameter Tests`.Integration {
    @Test
    func `stored existential properties are not parameters`() {
        let findings = Lint.Rule.`existential parameter Tests`.findings(
            "struct Box { let value: any View }",
            file: "/workspace/swift-fixture/Sources/Fixture/Box.swift"
        )
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`existential parameter Tests`.`Edge Case` {
    @Test
    func `Codable requirement witnesses are admitted`() {
        let findings = Lint.Rule.`existential parameter Tests`.findings(
            """
            extension Box: Encodable {
              public func encode(to encoder: any Encoder) throws(any Error) {}
            }
            extension Box: Decodable {
              public init(from decoder: any Swift.Decoder) throws(any Error) {}
            }
            """
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `Encoder and Decoder outside the Codable witnesses are still flagged`() {
        let findings = Lint.Rule.`existential parameter Tests`.findings(
            """
            func log(_ encoder: any Encoder) {}
            func encode(to sink: any Sink) {}
            func encode(to encoder: any Encoder, options: Int) {}
            init(decoder: any Decoder) {}
            init(from source: any Source) {}
            static func make(from decoder: any Decoder) {}
            """
        )
        #expect(findings.count == 6)
    }

    @Test
    func `witness shapes are flagged without a Codable conformance on the enclosing declaration`() {
        let findings = Lint.Rule.`existential parameter Tests`.findings(
            """
            extension Box {
              func encode(to encoder: any Encoder) throws {}
            }
            extension Box: Hashable {
              init(from decoder: any Decoder) throws {}
            }
            extension Box: Encodable {
              init(from decoder: any Decoder) throws {}
            }
            func encode(to encoder: any Encoder) {}
            """
        )
        #expect(findings.count == 4)
    }

    @Test
    func `nested CodingKeys do not hide the enclosing conformance`() {
        let findings = Lint.Rule.`existential parameter Tests`.findings(
            """
            extension Box: Swift.Codable {
              private enum CodingKeys: String, CodingKey { case value }
              public init(from decoder: any Swift.Decoder) throws {}
              public func encode(to encoder: any Swift.Encoder) throws {}
            }
            """
        )
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`existential parameter Tests`.`Edge Case` {
    @Test
    func `a collection of existentials names the heterogeneous alternatives`() {
        let findings = Lint.Rule.`existential parameter Tests`.findings(
            """
            func render(_ view: any View, fallback: (any View)?, into sinks: [any Sink]) {}
            """
        )
        #expect(findings.count == 3)
        #expect(findings[0].message.contains("take `some P`"))
        #expect(findings[1].message.contains("take `some P`"))
        #expect(findings[2].message.contains("parameter pack"))
    }
}
