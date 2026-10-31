public import Lint

extension Lint.SQL {

    public struct Exception: Sendable, Hashable {

        public let file: Swift::String

        public let declaration: Swift::String

        public let sites: Swift::Int

        public let reason: Swift::String

        public init(
            file: Swift::String,
            declaration: Swift::String,
            sites: Swift::Int = 1,
            reason: Swift::String
        ) {
            self.file = file
            self.declaration = declaration
            self.sites = sites
            self.reason = reason
        }
    }
}

extension Lint.SQL.Exception {

    package var label: Swift::String {
        "`\(declaration)` in `\(file)`"
    }
}
