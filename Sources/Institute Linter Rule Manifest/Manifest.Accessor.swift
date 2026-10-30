internal import Lint
internal import SwiftSyntax

internal func manifestAccessorBodies(
    in file: SourceFileSyntax,
    extendedTypes: Swift::Set<Swift::String>,
    static requiredStatic: Swift::Bool
) -> [Swift::String: ExprSyntax] {
    var bodies: [Swift::String: ExprSyntax] = [:]
    for statement in Lint.Syntax.Conditional.statements(file.statements) {
        guard let extensionDecl = statement.item.as(ExtensionDeclSyntax.self),
            extendedTypes.contains(extensionDecl.extendedType.trimmedDescription)
        else { continue }

        for member in extensionDecl.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
            let isStatic = variable.modifiers.contains {
                $0.name.tokenKind == .keyword(.static)
            }
            guard isStatic == requiredStatic else { continue }

            for binding in variable.bindings {
                guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                    let expression = manifestAccessorExpression(binding)
                else { continue }
                bodies[pattern.identifier.text] = expression
            }
        }
    }
    return bodies
}

private func manifestAccessorExpression(_ binding: PatternBindingSyntax) -> ExprSyntax? {
    if let initializer = binding.initializer?.value {
        return initializer
    }
    guard let accessorBlock = binding.accessorBlock,
        case .getter(let items) = accessorBlock.accessors,
        items.count == 1,
        let item = items.first
    else { return nil }
    return item.item.as(ExprSyntax.self)
}

internal func manifestResolvedString(
    _ expression: ExprSyntax,
    staticAccessors: [Swift::String: ExprSyntax],
    instanceAccessors: [Swift::String: ExprSyntax],
    receiver: Swift::String? = nil,
    visited: Swift::Set<Swift::String> = [],
    unhandledSourceShape: inout Swift::String?
) -> Swift::String? {
    if let literal = expression.as(StringLiteralExprSyntax.self) {
        return manifestStringLiteralText(literal)
    }

    if let reference = expression.as(DeclReferenceExprSyntax.self),
        reference.baseName.text == "self",
        let receiver
    {
        return receiver
    }

    if let member = expression.as(MemberAccessExprSyntax.self) {
        let name = member.declName.baseName.text
        if let base = member.base {
            guard
                let resolvedBase = manifestResolvedString(
                    base,
                    staticAccessors: staticAccessors,
                    instanceAccessors: instanceAccessors,
                    receiver: receiver,
                    visited: visited,
                    unhandledSourceShape: &unhandledSourceShape
                )
            else { return nil }
            let key = "instance:\(name)"
            guard !visited.contains(key), let body = instanceAccessors[name] else {
                unhandledSourceShape =
                    unhandledSourceShape ?? "unresolved manifest string accessor '\(name)'"
                return nil
            }
            return manifestResolvedString(
                body,
                staticAccessors: staticAccessors,
                instanceAccessors: instanceAccessors,
                receiver: resolvedBase,
                visited: visited.union([key]),
                unhandledSourceShape: &unhandledSourceShape
            )
        }

        let key = "static:\(name)"
        guard !visited.contains(key), let body = staticAccessors[name] else {
            unhandledSourceShape =
                unhandledSourceShape ?? "unresolved manifest string accessor '\(name)'"
            return nil
        }
        return manifestResolvedString(
            body,
            staticAccessors: staticAccessors,
            instanceAccessors: instanceAccessors,
            receiver: receiver,
            visited: visited.union([key]),
            unhandledSourceShape: &unhandledSourceShape
        )
    }

    if let sequence = expression.as(SequenceExprSyntax.self) {
        var text = ""
        for (index, element) in sequence.elements.enumerated() {
            if index % 2 == 0 {
                guard
                    let part = manifestResolvedString(
                        element,
                        staticAccessors: staticAccessors,
                        instanceAccessors: instanceAccessors,
                        receiver: receiver,
                        visited: visited,
                        unhandledSourceShape: &unhandledSourceShape
                    )
                else { return nil }
                text += part
            } else {
                guard let binaryOperator = element.as(BinaryOperatorExprSyntax.self),
                    binaryOperator.operator.text == "+"
                else {
                    unhandledSourceShape =
                        unhandledSourceShape
                        ?? "unsupported manifest string expression '\(expression.trimmedDescription)'"
                    return nil
                }
            }
        }
        return text
    }

    if let infix = expression.as(InfixOperatorExprSyntax.self),
        let binaryOperator = infix.operator.as(BinaryOperatorExprSyntax.self),
        binaryOperator.operator.text == "+",
        let left = manifestResolvedString(
            infix.leftOperand,
            staticAccessors: staticAccessors,
            instanceAccessors: instanceAccessors,
            receiver: receiver,
            visited: visited,
            unhandledSourceShape: &unhandledSourceShape
        ),
        let right = manifestResolvedString(
            infix.rightOperand,
            staticAccessors: staticAccessors,
            instanceAccessors: instanceAccessors,
            receiver: receiver,
            visited: visited,
            unhandledSourceShape: &unhandledSourceShape
        )
    {
        return left + right
    }

    unhandledSourceShape =
        unhandledSourceShape
        ?? "unsupported manifest string expression '\(expression.trimmedDescription)'"
    return nil
}

internal func manifestStringLiteralText(_ literal: StringLiteralExprSyntax) -> Swift::String? {
    guard literal.segments.count == 1,
        let segment = literal.segments.first,
        let stringSegment = segment.as(StringSegmentSyntax.self)
    else { return nil }
    return stringSegment.content.text
}
