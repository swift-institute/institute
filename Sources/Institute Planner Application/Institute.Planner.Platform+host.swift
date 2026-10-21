public import Institute_Model

extension Institute.Planner.Platform {
    /// The platform this process runs on, or `nil` where no planner is
    /// published.
    public static var host: Self? {
        #if os(macOS) && arch(arm64)
            .macos
        #elseif os(Linux) && arch(x86_64)
            .linux
        #else
            nil
        #endif
    }
}
