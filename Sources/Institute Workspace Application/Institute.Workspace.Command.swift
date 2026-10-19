import Environment
import File_System
public import Institute_Model

extension Institute.Workspace.Command {
    /// Resolves the Institute root from the working directory.
    static func root() throws(Institute.Error) -> Institute.Root {
        guard let working = Environment.read("PWD") else {
            throw .configuration("PWD is not available")
        }
        let checkout: File.Directory
        do throws(File.Path.Error) {
            checkout = try File.Directory(validating: working)
        } catch {
            throw .configuration("Institute checkout is not a valid path: \(error)")
        }
        return try Institute.Root(checkout: checkout)
    }
}
