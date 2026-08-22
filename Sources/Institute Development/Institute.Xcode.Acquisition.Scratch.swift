internal import File_System
internal import Institute_Model

extension Institute.Xcode.Acquisition {
    static func withScratch<Result: Sendable>(
        at root: Institute.Root,
        _ operation: @Sendable (File.Directory) async throws(Institute.Error) -> Result
    ) async throws(Institute.Error) -> Result {
        let path: File.Path
        do throws(File.Path.Temporary.Error) {
            path = try File.Path.Temporary.sibling(
                of: root.checkout.path,
                prefix: ".institute-catalog-"
            )
        } catch {
            throw .filesystem("cannot allocate target-catalog scratch: \(error)")
        }
        let scratch = File.Directory(path)
        do {
            try await scratch.create.recursive()
        } catch {
            throw .filesystem("cannot create target-catalog scratch \(scratch): \(error)")
        }

        do throws(Institute.Error) {
            let result = try await operation(scratch)
            try remove(scratch)
            return result
        } catch {
            let operationError = error
            do throws(Institute.Error) {
                try remove(scratch)
            } catch {
                throw .filesystem(
                    "target catalog acquisition failed with \(operationError), and scratch "
                        + "cleanup failed: \(error)"
                )
            }
            throw operationError
        }
    }

    private static func remove(
        _ directory: File.Directory
    ) throws(Institute.Error) {
        do throws(File.System.Delete.Error) {
            try directory.delete.recursive()
        } catch {
            throw .filesystem("cannot remove target-catalog scratch \(directory): \(error)")
        }
    }
}
