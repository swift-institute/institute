public import Institute_Model

extension Institute.Shader {
    /// A generated file, with what it holds and what it should hold.
    public struct Generated: Sendable {
        // swift-linter:disable:next raw concept
        // REASON: a path inside the repository as Git lists it, written with / on every platform; looked at File.Path.
        public var path: Swift.String
        public var current: Swift.String
        public var wanted: Swift.String

        public var fresh: Swift.Bool { current == wanted }
    }
}
