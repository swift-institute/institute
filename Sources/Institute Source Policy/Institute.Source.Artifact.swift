internal import Byte
internal import FIPS_180_4
public import Institute_Model
public import Source_Profile

extension Institute.Source {
    public struct Artifact: Equatable, Sendable {
        // swift-linter:disable:next raw concept
        // REASON: a path inside the repository as Git lists it, with / on every platform, compared whole and written to the report's JSON; looked at Path and File.Path, which Win32 spells with \ and which add a parse that can fail.
        public let path: Swift.String
        public let contents: Swift.String
        public let digest: Source_Profile::Source.Profile.Digest
        public let schema: Swift.String

        // swift-linter:disable:next raw concept
        // REASON: a path inside the repository as Git lists it, with / on every platform, compared whole and written to the report's JSON; looked at Path and File.Path, which Win32 spells with \ and which add a parse that can fail.
        public init(path: Swift.String, contents: Swift.String, schema: Swift.String) {
            self.path = path
            self.contents = contents
            self.schema = schema
            self.digest = .init(
                FIPS_180_4.SHA256.digest(contents.utf8.map(Byte.init(_:))).hex
            )
        }
    }
}
