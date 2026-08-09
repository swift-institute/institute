import Standard_Library_Extensions
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

extension Institute.Context.Packet {
  @Suite
  struct Test {}
}

extension Institute.Context.Packet.Test {
  @Test
  func `key accepts a canonical Issue coordinate only`() {
    #expect(
      Institute.Context.Packet.Key(argument: "swift-institute/institute-application#100")?.identity
        == "swift-institute/institute-application#100")
    #expect(
      Institute.Context.Packet.Key(argument: "swift-institute/institute-application#0") == nil)
    #expect(Institute.Context.Packet.Key(argument: "swift-institute/institute-application") == nil)
    #expect(
      Institute.Context.Packet.Key(argument: "swift-institute/institute-application#one") == nil)
  }

  @Test
  func `report has deterministic bounded JSON and states its continuation`() {
    let report = Institute.Context.Packet.Report(
      record: .init(
        key: Institute.Context.Packet.Key(argument: "swift-institute/institute-application#100")!,
        title: "Render a packet",
        state: "open",
        type: "Task",
        stateReason: nil,
        url: "https://github.com/swift-institute/institute-application/issues/100",
        body: String(repeating: "state ", count: 300),
        assignees: ["coenttb"],
        labels: ["task"],
        parent: "swift-institute/.github#126",
        children: ["swift-institute/institute-application#101"],
        comments: [],
        divergences: [],
        diagnostics: []
      ),
      diagnostics: [],
      maxBytes: 512
    )

    let first = report.render(.json)
    let second = report.render(.json)
    #expect(first == second)
    #expect(first.utf8.count <= 512)
    #expect(first.contains("continuation"))
    #expect(report.status == 0)
  }

  @Test
  func `incomplete evidence exits two rather than looking clean`() {
    let report = Institute.Context.Packet.Report(
      record: nil, diagnostics: ["GitHub unavailable"], maxBytes: 24_000)
    #expect(report.status == 2)
    #expect(report.render(.human).contains("incomplete"))
  }

  @Test
  func `human packet truncation preserves a non ASCII scalar boundary`() {
    let record = Institute.Context.Packet.Record(
      key: Institute.Context.Packet.Key(argument: "swift-institute/institute-application#100")!,
      title: Swift.String(repeating: "€", count: 400),
      state: "open",
      type: "Task",
      stateReason: nil,
      url: "https://github.com/swift-institute/institute-application/issues/100",
      body: "",
      assignees: [], labels: [], parent: nil, children: [], comments: [],
      divergences: [], diagnostics: []
    )

    // 512 was the originally chosen bound, but at exactly 512 bytes the
    // continuation marker's digit count happens to make the raw title
    // budget an exact multiple of "€".utf8.count (3), which defeats the
    // very property this test exists to demonstrate — see #110. 501
    // keeps the same truncation shape (still far short of the full
    // 1200-byte title) without that coincidental alignment.
    let maxBytes = 501
    let rendered = Institute.Context.Packet.Report(
      record: record, diagnostics: [], maxBytes: maxBytes
    ).render(.human)
    let marker = rendered.range(of: "\ncontinuation:")!
    let title = rendered.range(of: "title: ")!
    let rawTitleBytes =
      maxBytes
      - rendered[marker.lowerBound...].utf8.count
      - rendered[..<title.upperBound].utf8.count
    let renderedTitle = rendered[title.upperBound..<marker.lowerBound]

    #expect(rendered.utf8.count <= maxBytes)
    #expect(!rendered.contains("\u{FFFD}"))
    #expect(rendered.contains("continuation:"))
    #expect(rawTitleBytes % "€".utf8.count != 0)
    #expect(renderedTitle.utf8.count % "€".utf8.count == 0)
  }

  @Test
  func `measured comment mismatch exits one`() {
    let record = Institute.Context.Packet.Record(
      key: Institute.Context.Packet.Key(argument: "swift-institute/institute-application#100")!,
      title: "Packet",
      state: "open",
      type: "Task",
      stateReason: nil,
      url: "https://github.com/swift-institute/institute-application/issues/100",
      body: "",
      assignees: [], labels: [], parent: nil, children: [], comments: [],
      divergences: ["included comment belongs to another Issue"], diagnostics: []
    )
    #expect(
      Institute.Context.Packet.Report(record: record, diagnostics: [], maxBytes: 24_000).status == 1
    )
  }
}
