package import SwiftSyntax

package final class PackageTargetImportEdgeImportVisitor: SyntaxVisitor {

    package var imports: [Swift::String: Swift::Int] = [:]
    private let converter: SourceLocationConverter

    package init(converter: SourceLocationConverter) {
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override package func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let first = node.path.first else { return .skipChildren }
        let module = first.name.text
        if imports[module] == nil {
            imports[module] =
                converter.location(
                    for: node.positionAfterSkippingLeadingTrivia
                ).line
        }
        return .skipChildren
    }
}
