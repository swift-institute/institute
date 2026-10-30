internal import SwiftSyntax

internal struct Primary {
    let node: DeclSyntax
    let namePosition: AbsolutePosition
    let extensionPrefix: Swift::String
    let wrappingExtension: ExtensionDeclSyntax?
}
