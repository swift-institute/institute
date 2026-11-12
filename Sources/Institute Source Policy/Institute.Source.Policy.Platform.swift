public import Institute_Model

extension Institute.Source.Policy {
    public enum Platform: Sendable, CaseIterable {
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

    /// The platform this process runs on, or `nil` where the policy pins no
    /// tools.
    public static var host: Self? {
        #if os(macOS) && arch(arm64)
            .macOSARM64
        #elseif os(Linux) && arch(x86_64)
            .linuxX86_64
        #else
            nil
        #endif
    }
}
