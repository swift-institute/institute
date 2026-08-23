import struct Swift.String
public import Institute_Model
public import Institute_CI_Model

// Pure-Swift spellings of the string operations the validation rules
// use, so the rules read as the predicates they publish and the target
// stays free of the Foundation module family.
extension StringProtocol {
    /// The string with ASCII and Unicode whitespace (including newlines)
    /// removed from both ends.
    internal var trimmedWhitespace: String {
        var text = Substring(self)
        while let first = text.first, first.isWhitespace {
            text = text.dropFirst()
        }
        while let last = text.last, last.isWhitespace {
            text = text.dropLast()
        }
        return String(text)
    }

    /// The final slash-separated component — the file name of a path.
    internal var finalPathComponent: String {
        guard let separator = lastIndex(of: "/") else { return String(self) }
        return String(self[index(after: separator)...])
    }

    /// Everything before the final slash-separated component — the
    /// directory of a path, or the empty string when there is none.
    internal var directoryPortion: String {
        guard let separator = lastIndex(of: "/") else { return "" }
        return String(self[..<separator])
    }
}
