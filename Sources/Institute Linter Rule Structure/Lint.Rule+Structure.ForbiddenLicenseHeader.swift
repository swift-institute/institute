internal import Cardinal
public import Lint
internal import Linter_Rule_Structure
internal import SwiftSyntax

extension Lint.Rule {

    public static let `forbidden license header` = Lint.Rule(
        id: "forbidden license header",
        default: .error,
        controls: [
            .init(
                id: "forbidden license header complete",
                source: "// Copyright (c) 2026 Example\n"
                    + "// Licensed under Apache License v2.0\n\nstruct Value {}",
                path: "Sources/Structure Core/Value.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "forbidden license header ordinary comment",
                source: "// Implementation note\nstruct Value {}",
                path: "Sources/Structure Core/Value.swift",
                expectation: .clean
            ),
            .init(
                id: "forbidden license header partial",
                source: "// Licensed under Apache License v2.0\nstruct Value {}",
                path: "Sources/Structure Core/Value.swift",
                expectation: .findings(1)
            ),
        ],
        observe: { source, severity in
            let recognition = Lint.License.Header.recognize(in: source.tree.description)
            switch recognition {
            case .absent:
                return Lint.Rule.Observation(findings: [], coverage: .measured)
            case .complete(let header):
                return Lint.Rule.Observation(
                    findings: [
                        forbiddenLicenseHeaderFinding(
                            source: source,
                            severity: severity,
                            line: Swift::Int(clamping: header.start) + 1
                        )
                    ],
                    coverage: .measured
                )
            case .refused(let refusal):
                return Lint.Rule.Observation(
                    findings: [
                        forbiddenLicenseHeaderFinding(
                            source: source,
                            severity: severity,
                            detail: "ambiguous leading license block: \(refusal)"
                        )
                    ],
                    coverage: .measured
                )
            }
        },
        repair: { source in
            switch Lint.License.Header.recognize(in: source.tree.description) {
            case .absent:
                .unchanged
            case .complete(let header):
                if let contents = header.removing(from: source.tree.description) {
                    .edits([.rewrite(path: source.path, contents: contents)])
                } else {
                    .refused(.ambiguousRepair("recognized header could not be removed"))
                }
            case .refused(let refusal):
                .refused(.ambiguousRepair("ambiguous leading license block: \(refusal)"))
            }
        }
    )
}

private func forbiddenLicenseHeaderFinding(
    source: borrowing Lint.Source.Parsed,
    severity: Diagnostic.Severity,
    line: Swift::Int = 1,
    detail: Swift::String = "remove the complete leading license block"
) -> Diagnostic.Record {
    Diagnostic.Record(
        location: Source.Location(
            fileID: source.file.fileID,
            filePath: source.file.filePath,
            line: line,
            column: 1
        ),
        severity: severity,
        identifier: "forbidden license header",
        message: "[forbidden license header]: Institute Swift source headers are forbidden; \(detail)"
    )
}
