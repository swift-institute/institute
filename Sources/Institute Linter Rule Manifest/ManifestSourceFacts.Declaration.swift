package import SwiftSyntax

extension ManifestSourceFacts {
    package struct Declaration: Sendable {
        /// The dotted path, without backticks or generic arguments: `IETF.RFC.3986.URI`.
        package let path: [Swift::String]
        /// The path together with the requirements of the extensions it is declared in and the `#if` conditions
        /// around it: two declarations are of one path only when their keys are equal.
        package let key: Swift::String
        package let kind: Kind
        package let isPublic: Swift::Bool
        package let position: AbsolutePosition
    }
}
