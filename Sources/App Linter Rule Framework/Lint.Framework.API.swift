import Lint

extension Lint.Framework {

    /// The calls that have one owner, by the word that names them.
    package enum API {}
}

extension Lint.Framework.API {

    /// Each owned name, with the suffix of the target that owns it; an empty owner means no target does.
    package static let owners: [Swift::String: Swift::String] = [
        "FileManager": " Foundation Integration",
        "NSFileCoordinator": " Foundation Integration",
        "NSFileVersion": " Foundation Integration",
        "NSMetadataQuery": " Foundation Integration",
        "startAccessingSecurityScopedResource": " Foundation Integration",
        "stopAccessingSecurityScopedResource": " Foundation Integration",
        "bookmarkData": " Foundation Integration",
        "resolvingBookmarkData": " Foundation Integration",
        "startDownloadingUbiquitousItem": " Foundation Integration",
        "contentsOf": " Foundation Integration",
        "thermalState": " Darwin",
        "isLowPowerModeEnabled": " Darwin",
        "beginActivity": " Darwin",
        "PDFDocument": " PDFKit",
        "PDFPage": " PDFKit",
        "JSONSerialization": "",
    ]

    package static func owns(_ target: Swift::String?, _ name: Swift::String) -> Swift::Bool {
        guard let suffix = owners[name], !suffix.isEmpty, let target else { return false }
        return target.count > suffix.count && target.hasSuffix(suffix)
    }
}
