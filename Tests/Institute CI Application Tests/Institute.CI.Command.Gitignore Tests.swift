import Institute_CI_Application
import Institute_CI_Model
public import Institute_Model
import Testing

@testable import Institute_CI_Canon

// The corpus-harness integration coverage for the gitignore rules lives
// with the corpus itself, in the institute package's CI Validation test
// suite; this suite owns only the command family's argument grammar and
// rendering seam.
extension Institute.CI.Command.Gitignore {
    @Suite
    struct Test {
        static let terminator = Institute.CI.Canon.Gitignore.terminator
        static let canon =
            "# CANONICAL\n/*\n!/Sources/\n"
            + Institute.CI.Canon.Gitignore.Capability.block
            + "\(terminator)\n"

        @Suite
        struct Unit {
            @Test func `render command parses exact policy inputs`() throws {
                #expect(
                    try Institute.CI.Command.Gitignore.parse([
                        "render-gitignore", "--canon", "canon.txt", "--target", ".gitignore",
                    ]) == .render(canon: "canon.txt", target: ".gitignore")
                )
            }

            @Test func `validator command parses repository inputs`() throws {
                #expect(
                    try Institute.CI.Command.Gitignore.parse([
                        "validate-gitignore", "--repository",
                        "swift-primitives/swift-byte-primitives",
                        "--root", "/tmp/subject", "--canon", "/tmp/canon.txt",
                    ])
                        == .validate(
                            repository: "swift-primitives/swift-byte-primitives",
                            root: "/tmp/subject",
                            canon: "/tmp/canon.txt"
                        )
                )
            }

            @Test func `renderer emits only complete canonical bytes`() throws {
                let rendered = try Institute.CI.Command.Gitignore.render(
                    canon: Institute.CI.Command.Gitignore.Test.canon,
                    target: "# tail\n"
                )
                #expect(rendered == Institute.CI.Command.Gitignore.Test.canon)
                #expect(!rendered.contains("# tail"))
            }
        }

        @Suite
        struct `Edge Case` {
            @Test func `malformed command refuses before evaluation`() {
                #expect(
                    throws: Institute.CI.Command.Gitignore.Error
                        .missingRequiredArgument("--root")
                ) {
                    _ = try Institute.CI.Command.Gitignore.parse([
                        "validate-gitignore", "--repository",
                        "swift-primitives/swift-byte-primitives",
                    ])
                }
            }
        }
    }
}
