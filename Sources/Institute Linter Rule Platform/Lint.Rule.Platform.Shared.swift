internal import SwiftSyntax

internal let platformPlatformTokens: Swift::Set<Swift::String> = [
    "Darwin", "Linux", "Windows", "Android", "WASI", "FreeBSD", "OpenBSD",
    "NetBSD", "BSD",
]

internal func platformIsPublicAPI(_ modifiers: DeclModifierListSyntax) -> Swift::Bool {
    for modifier in modifiers {
        switch modifier.name.tokenKind {
        case .keyword(.public), .keyword(.open):
            return true

        default:
            continue
        }
    }
    return false
}

internal func platformIsPublicAPIEffective(
    _ node: Syntax,
    modifiers: DeclModifierListSyntax
) -> Swift::Bool {
    if platformIsPublicAPI(modifiers) {
        return true
    }
    var current: Syntax? = node.parent
    while let candidate = current {
        if let ext = candidate.as(ExtensionDeclSyntax.self) {
            return platformIsPublicAPI(ext.modifiers)
        }
        current = candidate.parent
    }
    return false
}
