internal import File_System
internal import Institute_Inventory
internal import Institute_Model

extension Institute.Context {
    struct Link: Sendable {
        let path: File.Path

        /// The stored link text (may be relative to the link's own
        /// directory; POSIX stores it verbatim).
        let target: File.Path

        /// The absolute path of the content the link exposes. Equal to
        /// ``target`` except for relative links, which name it
        /// explicitly. The Windows materialization contract verifies
        /// against this.
        let canonical: File.Path

        init(path: File.Path, target: File.Path, canonical: File.Path? = nil) {
            self.path = path
            self.target = target
            self.canonical = canonical ?? target
        }
    }
}
