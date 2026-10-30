internal import SwiftSyntax

internal func memoryTriviaHasAdjacentComment(
    _ trivia: Trivia,
    matching isWanted: (Swift::String) -> Swift::Bool
) -> Swift::Bool {
    var newlineRun = 0
    for piece in Swift::Array(trivia).reversed() {
        switch piece {
        case .newlines(let count), .carriageReturns(let count), .carriageReturnLineFeeds(let count):
            newlineRun += count
            if newlineRun >= 2 { return false }

        case .lineComment(let text):
            newlineRun = 0
            let trimmed = text.trimmingPrefix("//")
            let body = trimmed.drop(while: { $0 == " " || $0 == "\t" })
            if isWanted(Swift::String(body)) {
                return true
            }
            continue

        case .docLineComment, .docBlockComment, .blockComment:
            newlineRun = 0
            continue

        case .spaces, .tabs:
            continue

        default:
            continue
        }
    }
    return false
}

internal func memoryWhereClauseHasPositiveCopyable(
    _ clause: GenericWhereClauseSyntax?
)
    -> Swift::Bool
{
    guard let clause else { return false }
    for requirement in clause.requirements {
        guard let conformance = requirement.requirement.as(ConformanceRequirementSyntax.self) else {
            continue
        }
        if memoryTypeMentionsPositiveCopyable(conformance.rightType) {
            return true
        }
    }
    return false
}

internal func memoryWhereClauseHasNoncopyable(
    _ clause: GenericWhereClauseSyntax?
)
    -> Swift::Bool
{
    guard let clause else { return false }
    for requirement in clause.requirements {
        guard let conformance = requirement.requirement.as(ConformanceRequirementSyntax.self) else {
            continue
        }
        if memoryTypeMentionsSuppressedCopyable(conformance.rightType) {
            return true
        }
    }
    return false
}

private func memoryTypeMentionsSuppressedCopyable(_ type: TypeSyntax) -> Swift::Bool {
    if let suppressed = type.as(SuppressedTypeSyntax.self) {
        return memoryTypeMentionsPositiveCopyable(suppressed.type)
    }
    if let composition = type.as(CompositionTypeSyntax.self) {
        for element in composition.elements {
            if memoryTypeMentionsSuppressedCopyable(element.type) {
                return true
            }
        }
    }
    return false
}

internal func memoryTypeMentionsPositiveCopyable(_ type: TypeSyntax) -> Swift::Bool {
    if let identifier = type.as(IdentifierTypeSyntax.self),
        identifier.name.text == "Copyable"
    {
        return true
    }
    if let member = type.as(MemberTypeSyntax.self),
        member.name.text == "Copyable",
        let base = member.baseType.as(IdentifierTypeSyntax.self),
        base.name.text == "Swift"
    {
        return true
    }
    if let composition = type.as(CompositionTypeSyntax.self) {
        for element in composition.elements {
            if memoryTypeMentionsPositiveCopyable(element.type) {
                return true
            }
        }
    }
    return false
}
