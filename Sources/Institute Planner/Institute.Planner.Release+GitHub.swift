import Byte
import File_System
import Institute_GitHub
public import Institute_Model

extension Institute.Planner.Release {
    /// The live `ci-binaries` release of swift-institute/institute, read and
    /// downloaded through `gh`.
    public static var github: Self {
        .init(
            names: { () throws(Institute.Planner.Error) in
                do throws(Institute.GitHub.Release.Error) {
                    return try Institute.GitHub.Release.assets(
                        repository: Institute.Planner.publisher,
                        tag: Institute.Planner.tag
                    )
                } catch {
                    throw .transport("cannot list the \(Institute.Planner.tag) release: \(error)")
                }
            },
            fetch: { name throws(Institute.Planner.Error) in
                let destination = try staging(name)
                defer {
                    // swift-linter:disable:next try optional
                    // REASON: cleanup of a private temporary file; a failed
                    // delete leaves only tmpdir residue and must not mask the
                    // download's own outcome.
                    try? File.System.Delete.delete(at: destination)
                }
                do throws(Institute.GitHub.Release.Error) {
                    try Institute.GitHub.Release.download(
                        repository: Institute.Planner.publisher,
                        tag: Institute.Planner.tag,
                        asset: name,
                        to: destination
                    )
                } catch {
                    if case .missing = error { throw .missing("release asset \(name)") }
                    throw .transport("cannot download \(name): \(error)")
                }
                return try Institute.Planner.read(destination)
            }
        )
    }

    /// A fresh private temporary path to download `name` into.
    private static func staging(_ name: Swift.String) throws(Institute.Planner.Error) -> File.Path {
        let anchor: File.Path
        do throws(File.Path.Error) {
            anchor = try File.Path.Temporary.deterministic(
                prefix: "institute-planner-asset",
                key: "",
                suffix: ""
            )
        } catch {
            throw .local("cannot resolve a temporary directory: \(error)")
        }
        do throws(File.Path.Temporary.Error) {
            return try File.Path.Temporary.sibling(of: anchor, prefix: "institute-planner-asset-")
        } catch {
            throw .local("cannot mint a download path for \(name): \(error)")
        }
    }
}
