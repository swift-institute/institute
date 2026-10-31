package import SwiftSyntax

package struct PackageTargetImportEdgeTarget {
    package var name: Swift::String = ""
    package var kind: Kind = .target
    package var explicitPath: Swift::String?
    package var dependencies: [Dependency] = []
    package var namePosition: AbsolutePosition = AbsolutePosition(utf8Offset: 0)
}
