import Git_Foundation
public import Institute_Model
import Process

extension Institute.Planner.Canary.Runner {
    /// This machine: clones through the Git client at depth one, and runs
    /// a planner with its summary streaming to this process's standard
    /// error and its report captured from standard output.
    public static var local: Self {
        .init(
            clone: { remote, directory throws(Institute.Planner.Error) in
                let git = Git.Client()
                let head: Git.Object.ID
                do throws(Git.Client.Error) {
                    try git.clone(remote, depth: 1, to: directory)
                    head = try git.head(at: directory)
                } catch {
                    throw .local("cannot clone \(remote): \(error)")
                }
                return try Institute.Planner.Revision(head.rawValue)
            },
            execute: { executable, arguments throws(Institute.Planner.Error) in
                let output: Process.Output
                do throws(Process.Error) {
                    output = try Process.Spawn.run(
                        .init(
                            executable: executable,
                            arguments: arguments,
                            stdout: .pipe,
                            stderr: .inherit
                        )
                    )
                } catch {
                    throw .local("cannot run \(executable): \(error)")
                }
                let code: Swift.Int32? =
                    if case .exited(let code) = output.status { code } else { nil }
                return .init(
                    code: code,
                    output: Swift.String(decoding: output.stdout ?? [], as: Swift.UTF8.self)
                )
            }
        )
    }
}
