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
