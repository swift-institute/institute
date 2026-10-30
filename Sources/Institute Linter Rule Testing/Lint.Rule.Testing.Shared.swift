internal import SwiftSyntax

internal func testingHasAttribute(
    _ attributes: AttributeListSyntax,
    named name: Swift::String
) -> Swift::Bool {
    for attribute in attributes {
        guard case .attribute(let attr) = attribute else { continue }
        let attributeName = attr.attributeName.trimmedDescription
        if attributeName == name || attributeName.hasSuffix(".\(name)") {
            return true
        }
    }
    return false
}
