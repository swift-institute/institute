import Foundation

enum BranchPinFoundation {
    static func resourcePath(forResource name: String, withExtension ext: String) -> String? {
        Bundle.module.url(forResource: name, withExtension: ext)?.path
    }

    static func writeTemporaryFleetPolicy(_ contents: String) throws -> String {
        let data = Data(contents.utf8)
        let path = FileManager.default.temporaryDirectory
            .appending(path: "fleet-policy-\(UUID().uuidString).json")
        try data.write(to: path)
        return path.path
    }
}
