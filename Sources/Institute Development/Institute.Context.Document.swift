internal import Institute_Model
internal import Institute_Inventory

internal import File_System

extension Institute.Context {
    struct Document: Sendable {
        let source: File
        let target: File
        let marker: Swift.String?

        init(source: File, target: File, marker: Swift.String? = nil) {
            self.source = source
            self.target = target
            self.marker = marker
        }
    }
}
