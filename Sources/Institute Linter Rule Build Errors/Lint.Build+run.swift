#if LinterRuleBuildErrors
    public import Lint
    internal import Byte
    internal import Linter_Rule_Scope
    internal import SwiftParser
    internal import SwiftSyntax

    extension Lint.Build {

        /// Runs `rules` over the files named in `arguments` and reports every finding as `path:line:column: error: message`,
        /// the form Xcode and SwiftPM show as a build error.
        ///
        /// A file that cannot be read, and a rule that cannot measure a file, are errors too: a build check that skips what
        /// it could not look at would report a clean build it has not seen. Suppression directives are not honoured, since
        /// the rules in the build-error bundle name hangs and defects that no comment may wave through.
        public static func run(
            arguments: [Swift::String],
            rules: [Lint.Rule.Configuration]
        ) -> Outcome {
            let parsed: Arguments
            do throws(Arguments.Error) {
                parsed = try Arguments.parse(arguments)
            } catch {
                return Outcome(lines: ["swift-linter-build-errors: \(error)", Arguments.usage], status: 64)
            }
            let enabled = rules.filter { $0.mode == .enabled }
            var records: [Diagnostic.Record] = []
            for file in parsed.files {
                records.append(contentsOf: check(file, root: parsed.root, rules: enabled))
            }
            records.sort()
            let errors = records.filter { $0.severity == .error }.count
            var lines = records.map { line(for: $0) }
            lines.append(
                "swift-linter-build-errors: \(parsed.files.count) files, \(enabled.count) rules, \(errors) errors"
            )
            return Outcome(lines: lines, status: errors == 0 ? 0 : 1, stamp: errors == 0 ? parsed.stamp : nil)
        }

        fileprivate static func check(
            _ file: Swift::String,
            root: Swift::String,
            rules: [Lint.Rule.Configuration]
        ) -> [Diagnostic.Record] {
            guard let text = Lint.Scope.File.text(at: file) else {
                return [
                    failure(
                        in: file,
                        rule: "build errors",
                        message: "[build errors]: this file could not be read, so no rule checked it."
                    )
                ]
            }
            let tree = Parser.parse(source: text)
            let converter = SourceLocationConverter(fileName: file, tree: tree)
            var manager = Source.Manager()
            let id = manager.register(fileID: file, filePath: file, content: [Byte](utf8: text))
            let parsed = Lint.Source.Parsed(
                file: manager.file(for: id),
                path: Lint.Source.Path(relative(file, to: root)),
                tree: tree,
                converter: converter
            )
            var records: [Diagnostic.Record] = []
            for entry in rules {
                let severity = entry.severity ?? entry.rule.severity.default
                let observation = entry.rule.observe(parsed, severity)
                records.append(contentsOf: observation.findings)
                if case .unmeasured = observation.coverage {
                    let identifier = entry.rule.id.underlying
                    records.append(
                        failure(
                            in: file,
                            rule: identifier,
                            message: "[\(identifier)]: the rule could not measure this file, so the build cannot vouch for it."
                        )
                    )
                }
            }
            return records
        }

        fileprivate static func relative(_ file: Swift::String, to root: Swift::String) -> Swift::String {
            let prefix = root.hasSuffix("/") ? root : root + "/"
            return file.hasPrefix(prefix) ? Swift::String(file.dropFirst(prefix.count)) : file
        }

        fileprivate static func failure(
            in file: Swift::String,
            rule: Swift::String,
            message: Swift::String
        ) -> Diagnostic.Record {
            let first: Swift::Int = 1
            return Diagnostic.Record(
                location: Source.Location(fileID: file, filePath: file, line: first, column: first),
                severity: .error,
                identifier: rule,
                message: message
            )
        }

        fileprivate static func line(for record: Diagnostic.Record) -> Swift::String {
            let location = record.location
            let severity: Swift::String =
                switch record.severity {
                case .error: "error"
                case .warning: "warning"
                case .note: "note"
                case .remark: "remark"
                }
            return "\(location.filePath ?? location.fileID):\(location.position): \(severity): \(record.message)"
        }
    }
#endif
