extension Source.Repair {
    public struct Evidence: Hashable, Sendable {
        public let file: Swift::String
        public let rule: Source.Rule.ID
        public let disposition: Disposition

        public init(file: Swift::String, rule: Source.Rule.ID, disposition: Disposition) {
            self.file = file
            self.rule = rule
            self.disposition = disposition
        }
    }
}

extension Source.Repair.Evidence {
    public static func refusals(for findings: [Source.Finding]) -> [Self] {
        var keys: Swift::Set<Swift::String> = []
        var evidence: [Self] = []
        for finding in findings {
            guard case .unavailable(let reason) = finding.repair,
                let file = finding.diagnostic.location.filePath,
                keys.insert(file + "\u{0}" + finding.rule.engine.token + "\u{0}" + finding.rule.token)
                    .inserted
            else { continue }
            evidence.append(.init(file: file, rule: finding.rule, disposition: .refused(reason)))
        }
        return evidence
    }
}
