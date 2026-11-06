public import Institute_Model

extension Institute.Repository.Policy.Census {
    /// One census coordinate; sixteen fields, censusVersion 1.
    public struct Row: Sendable, Equatable {
        // swift-linter:disable:next raw concept
        // REASON: the census format's version, a CI wire field written as 1; looked at Version, whose Version.Semantic needs three components.
        public var censusVersion: String
        // swift-linter:disable:next raw concept
        // REASON: the subject a census row names, a CI wire field: real rows hold owner/name, sentinel rows a label such as `sentinel` or `17-organization fleet`; looked at GitHub.Repository.Slug, which refuses those labels.
        public var repository: String
        public var headSha: String
        // swift-linter:disable:next raw concept
        // REASON: a field of a census row, a CI wire format: sentinel rows spell it empty, which File.Path refuses.
        public var path: String
        public var coordinateKind: Kind
        public var coordinateId: String
        public var line: Int
        public var engine: String
        // swift-linter:disable:next raw concept
        // REASON: a census row's excerpt digest as the wire format spells it; sentinel rows write it empty, which FIPS_180_4.Digest refuses; looked at FIPS_180_4.Digest.
        public var excerptSha256: String
        public var family: String
        public var intendedOwner: String
        public var disposition: String
        public var measurement: String
        public var cause: String
        public var generatedBy: String
        public var notes: String

        public init(
            // swift-linter:disable:next raw concept
            // REASON: the census format's version, a CI wire field written as 1; looked at Version, whose Version.Semantic needs three components.
            censusVersion: String = "1",
            // swift-linter:disable:next raw concept
            // REASON: the subject a census row names, a CI wire field: real rows hold owner/name, sentinel rows a label such as `sentinel` or `17-organization fleet`; looked at GitHub.Repository.Slug, which refuses those labels.
            repository: String,
            headSha: String,
            // swift-linter:disable:next raw concept
            // REASON: a field of a census row, a CI wire format: sentinel rows spell it empty, which File.Path refuses.
            path: String,
            coordinateKind: Kind,
            coordinateId: String,
            line: Int,
            engine: String,
            // swift-linter:disable:next raw concept
            // REASON: a census row's excerpt digest as the wire format spells it; sentinel rows write it empty, which FIPS_180_4.Digest refuses; looked at FIPS_180_4.Digest.
            excerptSha256: String,
            family: String,
            intendedOwner: String,
            disposition: String,
            measurement: String = "MEASURED",
            cause: String = "",
            generatedBy: String = "repository-policy census",
            notes: String = ""
        ) {
            self.censusVersion = censusVersion
            self.repository = repository
            self.headSha = headSha
            self.path = path
            self.coordinateKind = coordinateKind
            self.coordinateId = coordinateId
            self.line = line
            self.engine = engine
            self.excerptSha256 = excerptSha256
            self.family = family
            self.intendedOwner = intendedOwner
            self.disposition = disposition
            self.measurement = measurement
            self.cause = cause
            self.generatedBy = generatedBy
            self.notes = notes
        }

        public var values: [String] {
            [
                censusVersion, repository, headSha, path,
                coordinateKind.rawValue, coordinateId, String(line), engine,
                excerptSha256, family, intendedOwner, disposition,
                measurement, cause, generatedBy, notes,
            ]
        }
    }
}
