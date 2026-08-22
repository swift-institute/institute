public import File_System
public import Institute_Model

extension Institute.Xcode.Publication {
    public struct Document: Sendable {
        public let file: File
        public let contents: Swift.String

        public init(file: File, contents: Swift.String) {
            self.file = file
            self.contents = contents
        }
    }
}
