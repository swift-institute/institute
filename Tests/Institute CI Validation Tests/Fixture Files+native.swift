import File_System

extension FixtureFiles {
    /// `path` spelled the way the validation's own path type spells it,
    /// with the platform's native separators.
    static func native(_ path: Swift.String) throws -> Swift.String {
        try File.Path(path).description
    }
}
