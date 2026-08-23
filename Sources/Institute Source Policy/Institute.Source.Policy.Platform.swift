public import Institute_Model

extension Institute.Source.Policy {
    public enum Platform: Sendable {
        case linuxX86_64
        case macOSARM64
    }
}

extension Institute.Source.Policy.Platform {
    public var token: Swift.String {
        switch self {
        case .linuxX86_64: "linux-x86_64"
        case .macOSARM64: "macos-arm64"
        }
    }
}
