internal import File_System
internal import Institute_Inventory
internal import Institute_Model

extension Institute.Context {
    struct Link: Sendable {
        let path: File.Path
        let target: File.Path
    }
}
