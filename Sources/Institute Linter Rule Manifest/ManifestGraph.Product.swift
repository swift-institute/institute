package import SwiftSyntax

extension ManifestGraph {
    package struct Product: Sendable {
        package let name: Swift::String
        package let targets: [Swift::String]
        package let position: AbsolutePosition
    }
}
