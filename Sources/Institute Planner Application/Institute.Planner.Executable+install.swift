import FIPS_180_4
import File_System
public import Institute_Development
public import Institute_Model

extension Institute.Planner.Executable {
    /// What an installation of this planner records: the revision and
    /// platform it is published for, the digests it was verified against,
    /// and the toolchain it was built with.
    public var identity: Swift.String {
        let toolchain = self.toolchain.split(separator: "\n").first.map(Swift.String.init) ?? ""
        return """
            planner-revision=\(row.revision)
            platform=\(row.platform.rawValue)
            binary-sha256=\(row.binary.hex)
            graph-sha256=\(row.graph.hex)
            toolchain=\(toolchain)

            """
    }

    /// Installs the verified binary into the account's managed directory and
    /// records its identity there. Nothing is built.
    public func install() throws(Institute.Error) -> Institute.Installation {
        let anchor: File.Path
        do throws(File.Path.Error) {
            anchor = try File.Path.Temporary.deterministic(
                prefix: "institute-installed-planner",
                key: "",
                suffix: ""
            )
        } catch {
            throw .filesystem("cannot resolve a temporary directory: \(error)")
        }
        let staging: File.Path
        do throws(File.Path.Temporary.Error) {
            staging = try File.Path.Temporary.sibling(of: anchor, prefix: "institute-installed-planner-")
        } catch {
            throw .filesystem("cannot mint a staging path for the planner: \(error)")
        }
        defer {
            // swift-linter:disable:next try optional
            // REASON: cleanup of a private temporary file; a failed delete
            // leaves only tmpdir residue and must not mask the install's own
            // outcome.
            try? File.System.Delete.delete(at: staging)
        }
        do throws(Institute.Planner.Error) {
            try Institute.Planner.write(binary, to: staging)
        } catch {
            throw .filesystem("cannot stage the planner: \(error)")
        }
        let installation = try Institute.Installation(installing: File(staging))
        try installation.install(recording: identity)
        return installation
    }
}
