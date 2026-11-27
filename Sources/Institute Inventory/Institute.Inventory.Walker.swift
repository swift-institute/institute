public import Institute_Model
internal import SwiftParser
internal import SwiftSyntax

extension Institute.Inventory {
    /// Reads one Swift source file into `Facts`, by syntax alone.
    ///
    /// Types are named by their dotted path, resolved through syntactic
    /// nesting and through the extended type of an enclosing extension.
    /// Types declared inside a function, accessor or closure body are local
    /// and left out. Every `#if` clause is read.
    public enum Walker {}
}

extension Institute.Inventory.Walker {
    public static func facts(source: Swift.String) -> Institute.Inventory.Facts {
        let tree = Parser.parse(source: source)
        let visitor = Visitor(tree: tree)
        visitor.walk(tree)
        var facts = visitor.facts
        facts.lines = Self.lines(source)
        return facts
    }

    static func lines(_ source: Swift.String) -> Swift.Int {
        var count = 0
        var last: Swift.UInt8 = 0x0A
        for byte in source.utf8 {
            if byte == 0x0A { count += 1 }
            last = byte
        }
        return last == 0x0A ? count : count + 1
    }
}
