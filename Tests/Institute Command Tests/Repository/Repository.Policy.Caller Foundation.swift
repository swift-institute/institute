import Foundation

enum CallerFoundation {
    static func replacingOccurrences(
        in text: Swift.String,
        of target: Swift.String,
        with replacement: Swift.String
    ) -> Swift.String {
        text.replacingOccurrences(of: target, with: replacement)
    }

    static func components(
        of text: Swift.String,
        separatedBy separator: Swift.String
    ) -> [Swift.String] {
        text.components(separatedBy: separator)
    }

    static func range(
        of literal: Swift.String,
        in text: Swift.String
    ) -> Swift.Range<Swift.String.Index>? {
        text.range(of: literal)
    }
}
