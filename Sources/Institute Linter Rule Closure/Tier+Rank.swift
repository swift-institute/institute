extension Tier {
    var rank: Swift::Int {
        switch self {
        case .setup: return 0
        case .body: return 1
        case .completion: return 2
        case .other: return 0
        }
    }
}
