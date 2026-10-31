internal import Lint
package import SwiftSyntax

extension Lint.SQL {

    package enum Statement {}
}

extension Lint.SQL.Statement {

    /// The schema objects `CREATE` and `DROP` name.
    package static let objects: Swift::Set<Swift::String> = ["TABLE", "INDEX", "TRIGGER", "VIEW"]

    /// The words that may stand between `CREATE` and its object.
    package static let modifiers: Swift::Set<Swift::String> = ["UNIQUE", "TEMP", "TEMPORARY", "VIRTUAL"]

    /// The statements a `WITH` clause leads into.
    package static let bodies: Swift::Set<Swift::String> = ["SELECT", "INSERT", "UPDATE", "DELETE", "REPLACE"]

    /// The words that make `BEGIN` a transaction.
    package static let transactions: Swift::Set<Swift::String> = ["TRANSACTION", "DEFERRED", "IMMEDIATE", "EXCLUSIVE"]

    package static func text(of literal: StringLiteralExprSyntax) -> Swift::String {
        var text = ""
        for segment in literal.segments {
            if let plain = segment.as(StringSegmentSyntax.self) {
                text += plain.content.text
            } else {
                text += " "
            }
        }
        return text
    }

    /// Whether `text` begins with an upper-case SQL statement in its clause shape: `SELECT … FROM`,
    /// `INSERT [OR …] INTO`, `REPLACE INTO`, `UPDATE … SET`, `DELETE FROM`, `CREATE [UNIQUE|TEMP|TEMPORARY|VIRTUAL]
    /// TABLE|INDEX|TRIGGER|VIEW`, `ALTER TABLE`, `DROP TABLE|INDEX|TRIGGER|VIEW`, `PRAGMA name`, `WITH … SELECT|INSERT|…`
    /// or `BEGIN TRANSACTION|DEFERRED|IMMEDIATE|EXCLUSIVE`. Case-sensitive: `"DELETE"` alone and
    /// `"Delete from library"` are not statements, and neither is lower-case SQL.
    package static func leads(_ text: Swift::String) -> Swift::Bool {
        let words = Self.words(in: text)
        guard let first = words.first, first.leading else { return false }
        let rest = words.dropFirst().map(\.text)
        switch first.text {
        case "SELECT": return rest.contains("FROM")
        case "INSERT": return rest.prefix(3).contains("INTO")
        case "REPLACE": return rest.first == "INTO"
        case "UPDATE": return rest.contains("SET")
        case "DELETE": return rest.first == "FROM"
        case "CREATE": return rest.first { !modifiers.contains($0) }.map(objects.contains) ?? false
        case "ALTER": return rest.first == "TABLE"
        case "DROP": return rest.first.map(objects.contains) ?? false
        case "PRAGMA": return !rest.isEmpty
        case "WITH": return rest.contains(where: bodies.contains)
        case "BEGIN": return rest.first.map(transactions.contains) ?? false
        default: return false
        }
    }

    fileprivate static func words(in text: Swift::String) -> [(text: Swift::String, leading: Swift::Bool)] {
        var words: [(text: Swift::String, leading: Swift::Bool)] = []
        var current = ""
        var seenContent = false
        var currentLeading = false
        func flush() {
            if !current.isEmpty {
                words.append((current, currentLeading))
                current = ""
            }
        }
        for character in text {
            if character.isASCII, character.isLetter || character.isNumber || character == "_" {
                if current.isEmpty {
                    currentLeading = !seenContent
                }
                current.append(character)
                seenContent = true
            } else {
                flush()
                if !character.isWhitespace {
                    seenContent = true
                }
            }
        }
        flush()
        return words
    }

    package static func isDirectArgumentOfSQLMacro(_ literal: StringLiteralExprSyntax) -> Swift::Bool {
        guard let argument = literal.parent?.as(LabeledExprSyntax.self),
            let list = argument.parent?.as(LabeledExprListSyntax.self),
            let owner = list.parent
        else { return false }
        return isSQLMacro(owner)
    }

    package static func isSQLMacro(_ node: Syntax) -> Swift::Bool {
        if let expansion = node.as(MacroExpansionExprSyntax.self) {
            return expansion.macroName.text == "sql"
        }
        if let expansion = node.as(MacroExpansionDeclSyntax.self) {
            return expansion.macroName.text == "sql"
        }
        return false
    }
}
