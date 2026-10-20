import Byte
import FIPS_180_4
import Institute_Model

@testable import Institute_Planner_Application

extension Institute.Planner {
    /// An in-memory `ci-binaries` release and consumer branch: asset and
    /// file names to bytes. Publishing a run adds the binary, graph and
    /// toolchain assets of both platforms and that run's PIN and SHA256SUMS
    /// assets, exactly as `publish-planner` names and lists them.
    struct Fixture: Sendable {
        static let candidate = String(repeating: "a", count: 40)
        static let current = String(repeating: "b", count: 40)

        var assets: [String: [Byte]] = [:]
        var files: [String: [Byte]] = [:]

        var release: Institute.Planner.Release {
            let assets = self.assets
            return .init(
                names: { () throws(Institute.Planner.Error) in assets.keys.sorted() },
                fetch: { name throws(Institute.Planner.Error) in
                    guard let bytes = assets[name] else { throw .missing("release asset \(name)") }
                    return bytes
                }
            )
        }

        var consumer: Institute.Planner.Consumer {
            let files = self.files
            return .init { path throws(Institute.Planner.Error) in
                guard let bytes = files[path] else { throw .missing("consumer \(path)") }
                return bytes
            }
        }

        static func hex(_ bytes: [Byte]) -> String {
            FIPS_180_4.SHA256.digest(bytes).hex
        }

        /// Publishes `revision` as run `run`, returning the PIN lines.
        @discardableResult
        mutating func publish(_ revision: String, run: String, salt: String = "") -> [String] {
            var rows: [String] = []
            var sums = ""
            for platform in Institute.Planner.Platform.allCases {
                let binary = [Byte](utf8: "binary \(platform.rawValue) \(revision) \(salt)\n")
                let graph = [Byte](utf8: "{\"pins\":[\"\(platform.rawValue)\(salt)\"]}\n")
                let toolchain = [Byte](utf8: "Swift version 6.4 (\(platform.rawValue))\n")
                let b = Self.hex(binary)
                let g = Self.hex(graph)
                assets["institute-\(platform.rawValue)-\(b)"] = binary
                assets["Package.resolved-\(platform.rawValue)-\(g)"] = graph
                assets["TOOLCHAIN-\(platform.rawValue)-\(b).txt"] = toolchain
                sums += "\(b)  institute-\(platform.rawValue)-\(b)\n"
                sums += "\(g)  Package.resolved-\(platform.rawValue)-\(g)\n"
                sums += "\(Self.hex(toolchain))  TOOLCHAIN-\(platform.rawValue)-\(b).txt\n"
                rows.append("\(revision) \(platform.rawValue) \(b) \(g)")
            }
            assets["PIN-\(revision)-\(run)"] = [Byte](utf8: rows.joined(separator: "\n") + "\n")
            assets["SHA256SUMS-\(revision)-\(run)"] = [Byte](utf8: sums)
            return rows
        }

        /// A consumer pinned to `revision` with `rows` adopted, under the
        /// comment headers the real files carry.
        mutating func adopt(_ revision: String, rows: [String]) {
            files[Institute.Planner.Consumer.pin] = [Byte](utf8: Self.pin(revision))
            files[Institute.Planner.Consumer.ledger] = [Byte](utf8: Self.ledger(rows))
        }

        static func pin(_ revision: String) -> String {
            "# The fleet's single planner-revision authority.\n# Exactly one 40-hex line; `#` lines are comments.\n\(revision)\n"
        }

        static func ledger(_ rows: [String]) -> String {
            "# Published planner binaries for the institute-ci action.\n# The last line for a revision and platform wins.\n"
                + rows.map { $0 + "\n" }.joined()
        }
    }
}
