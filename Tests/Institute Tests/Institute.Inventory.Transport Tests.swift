import HTTP_Standard
import Testing

@testable import Institute_Model
@testable import Institute_Inventory
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Lint
@testable import Institute_Pages
@testable import Institute_Doctor
@testable import Institute_Conversion
@testable import Institute_Instruments

@Suite
struct `Institute Inventory Transport Tests` {

    /// The shape `gh api -i` actually emits, verified against a live call:
    /// status line, header fields, a blank line, then the body.
    private static let sample = """
        HTTP/2.0 200 OK
        Content-Type: application/json; charset=utf-8
        Link: <https://api.github.com/organizations/253883464/repos?per_page=2&page=2>; rel="next"

        [{"name":"swift-dimension-primitives"}]
        """

    @Test
    func `parses the status line, headers, and body`() throws {
        let response = try Institute.Inventory.Transport.parse([UInt8](Self.sample.utf8))

        #expect(response.status.code == 200)
        #expect(response.headers.first("Content-Type")?.rawValue == "application/json; charset=utf-8")
        // The body must survive. An empty body here surfaces to the caller as
        // "empty input" from its JSON decoder, naming neither gh nor this
        // transport — the failure that looks like a different bug.
        let body = try #require(response.body)
        #expect(!body.isEmpty)
        #expect(
            Swift.String(decoding: body, as: Swift.UTF8.self)
                == #"[{"name":"swift-dimension-primitives"}]"#
        )
    }

    @Test
    func `carries the Link header that drives pagination`() throws {
        let response = try Institute.Inventory.Transport.parse([UInt8](Self.sample.utf8))
        let link = try #require(response.headers.first("Link"))
        // Without rel="next" reaching the pagination witness, discovery stops
        // after page one and under-reports silently.
        #expect(link.rawValue.contains(#"rel="next""#))
    }

    @Test
    func `survives CRLF line endings`() throws {
        let crlf = Self.sample.split(separator: "\n", omittingEmptySubsequences: false)
            .joined(separator: "\r\n")
        let response = try Institute.Inventory.Transport.parse([UInt8](crlf.utf8))

        #expect(response.status.code == 200)
        // A stray \r left on a captured value silently corrupts the field; for
        // Link that ends pagination early.
        #expect(response.headers.first("Content-Type")?.rawValue == "application/json; charset=utf-8")
        let body = try #require(response.body)
        #expect(
            Swift.String(decoding: body, as: Swift.UTF8.self)
                == #"[{"name":"swift-dimension-primitives"}]"#
        )
    }

    @Test
    func `rejects output with no status line`() {
        #expect(throws: Institute.Inventory.Transport.Error.self) {
            try Institute.Inventory.Transport.parse([UInt8]("".utf8))
        }
    }
}
