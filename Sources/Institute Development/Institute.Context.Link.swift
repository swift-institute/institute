internal import Institute_Model
internal import Institute_Inventory

internal import File_System

extension Institute.Context {
    struct Link: Sendable {
        let path: File.Path
        let target: File.Path

        init(path: File.Path, target: File.Path) {
            self.path = path
            self.target = target
        }
    }
}
