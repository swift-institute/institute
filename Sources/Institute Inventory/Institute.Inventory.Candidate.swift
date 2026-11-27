public import Institute_Model

extension Institute.Inventory {
    /// A declared type a written chain may name.
    public struct Candidate: Sendable, Hashable {
        /// The declared path, joined with dots.
        // swift-linter:disable:next raw concept
        // REASON: a declared type's dotted path, such as Picture.Encoded.Pixel, as types.json spells it; it names no file.
        public var path: Swift.String
        /// The declaring target, an index into the caller's target list.
        public var target: Swift.Int
    }
}
