public import File_System
public import Institute_Model
public import JSON

extension Institute.Source.Preparation {
    /// The receipt the last `institute source prepare` wrote for `workspace`.
    ///
    /// - Throws: ``Institute/Error`` when no receipt exists — the workspace
    ///   was never prepared — or when the receipt does not parse.
    public static func read(
        workspace: Swift.String
    ) throws(Institute.Error) -> Self {
        let directory = try Institute.Source.Application.artifactDirectory(workspace: workspace)
        let receipt = directory[file: "receipt.json"]
        let bytes: [Byte]
        do throws(Either<File.System.Read.Full.Error, Never>) {
            bytes = try File.System.Read.Full.read(from: receipt.path) { span in
                var result: [Byte] = []
                result.reserveCapacity(span.count)
                for index in span.indices { result.append(span[index]) }
                return result
            }
        } catch { throw .configuration("source preparation missing; run source prepare") }
        do throws(JSON.Error) {
            return try .init(jsonString: Swift.String(decoding: bytes, as: Swift.UTF8.self))
        } catch { throw .configuration("source preparation receipt is malformed: \(error)") }
    }
}
