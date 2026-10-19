public import File_System
public import Institute_Model

extension Institute.Sync {
    /// The planned materialization of one self-hosting workspace control.
    ///
    /// Controls are not inventory entries, so `Institute.Layout` does not
    /// place them; their checkout is fixed by the workspace location they
    /// carry. A present checkout is the contributor's own and is left as it
    /// is. An absent one is cloned, because the integration workspace names
    /// every control and acquisition refuses a member without a manifest.
    public struct Control: Sendable {
        public let control: Institute.Workspace.Control
        /// The checkout path relative to the hierarchy root.
        public let reference: Swift.String
        public let directory: File.Directory
        public let url: Swift.String
        public let action: Institute.Action

        public init(
            control: Institute.Workspace.Control,
            reference: Swift.String,
            directory: File.Directory,
            url: Swift.String,
            action: Institute.Action
        ) {
            self.control = control
            self.reference = reference
            self.directory = directory
            self.url = url
            self.action = action
        }
    }
}
