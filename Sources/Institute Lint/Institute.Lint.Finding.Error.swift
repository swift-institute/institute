internal import Institute_Development
internal import Institute_Model

extension Institute.Lint.Finding {
    /// Why a purported structured finding document cannot be consumed.
    package enum Error: Swift.Error, Equatable, Sendable, CustomStringConvertible {
        case malformed(Swift.String)
    }
}

extension Institute.Lint.Finding.Error {
    package var description: Swift.String {
        switch self {
        case .malformed(let reason): reason
        }
    }
}
