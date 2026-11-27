import Institute_Model
import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Architecture

extension Lint.Rule {
    @Suite struct Phrasing {
        @Test func `capability before noun controls hold`() {
            for outcome in Lint.Rule.`capability before noun`.outcomes() {
                #expect(outcome.holds, "\(outcome)")
            }
            let formatterRepo = Institute.Repository.Coordinate(organization: .`swift-atoms`, name: "swift-formatter")
            for outcome in Lint.Rule.`capability before noun`(in: formatterRepo).outcomes() {
                #expect(outcome.holds, "\(outcome)")
            }
        }

        @Test func `cross package type splice controls hold`() {
            for outcome in Lint.Rule.`cross package type splice`.outcomes() {
                #expect(outcome.holds, "\(outcome)")
            }
            let repos: [Institute.Repository.Coordinate] = [
                .init(organization: .`swift-atoms`, name: "swift-time"),
                .init(organization: .`swift-molecules`, name: "swift-buffer-linear"),
                .init(organization: .`swift-compositions`, name: "swift-picture-watercolor"),
                .init(organization: .`swift-compositions`, name: "swift-picture"),
                .init(organization: .`swift-linux-foundation`, name: "swift-linux-standard"),
                .init(organization: .`swift-compositions`, name: "swift-motion-reel"),
                .init(organization: .`swift-compositions`, name: "swift-transcript-heard"),
            ]
            for repo in repos {
                for outcome in Lint.Rule.`cross package type splice`(in: repo).outcomes() {
                    #expect(outcome.holds, "\(repo.name): \(outcome)")
                }
            }
        }

        @Test func `cross package type splice allows the path its package name owns`() {
            let source = """
                extension Transcript {
                    public enum Dictation {}
                }
                extension Transcript.Dictation {
                    public struct Segment {
                        public struct Word {}
                    }
                }
                """
            let named = Institute.Repository.Coordinate(
                organization: .`swift-compositions`,
                name: "swift-transcript-dictation"
            )
            let other = Institute.Repository.Coordinate(organization: .`swift-compositions`, name: "swift-picture")
            let file = "/workspace/repo/Sources/Transcript Dictation/Transcript.Dictation.swift"
            let namedSource = Lint.Source.parsed(from: source, file: file)
            let otherSource = Lint.Source.parsed(from: source, file: file)
            #expect(Lint.Rule.`cross package type splice`(in: named).observe(namedSource, .warning).findings.isEmpty)
            #expect(Lint.Rule.`cross package type splice`(in: other).observe(otherSource, .warning).findings.count == 2)
        }

        @Test func `domain nesting depth controls hold`() {
            for outcome in Lint.Rule.`domain nesting depth`.outcomes() {
                #expect(outcome.holds, "\(outcome)")
            }
            for outcome in Lint.Rule.`product domain nesting depth`.outcomes() {
                #expect(outcome.holds, "\(outcome)")
            }
            let standardRepo = Institute.Repository.Coordinate(organization: .`swift-iso`, name: "swift-iso-9945")
            for outcome in Lint.Rule.`domain nesting depth`(in: standardRepo).outcomes() {
                #expect(outcome.holds, "\(outcome)")
            }
        }
    }
}
