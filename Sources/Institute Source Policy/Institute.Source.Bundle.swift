public import Institute_Model

extension Institute.Source {
    public enum Bundle: Swift.String, CaseIterable, Sendable {
        case primitives
        case standards
        case institute
    }
}

extension Institute.Source.Bundle {
    public var token: Swift.String { rawValue }
}
