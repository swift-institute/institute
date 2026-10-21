import Byte
public import Institute_Model
import Process

extension Institute.Planner.Consumer {
    /// The live default branch of swift-institute/.github, read from its
    /// public raw-content host. It needs no credential, so it reads the same
    /// on a developer machine and on a hosted runner, like the `institute-ci`
    /// action does.
    public static var published: Self {
        .init { path throws(Institute.Planner.Error) in
            let address =
                "https://raw.githubusercontent.com/\(Institute.Planner.consumer)/main/\(path)"
            let output: Process.Output
            do throws(Process.Error) {
                output = try Process.Spawn.run(
                    .init(
                        executable: "/usr/bin/env",
                        arguments: [
                            "curl", "--fail", "--silent", "--show-error", "--location",
                            "--retry", "3", address,
                        ],
                        stdout: .pipe,
                        stderr: .pipe
                    )
                )
            } catch {
                throw .transport("cannot execute curl: \(error)")
            }
            guard case .exited(let code) = output.status, code == 0 else {
                let message = Swift.String(decoding: output.stderr ?? [], as: Swift.UTF8.self)
                throw .transport("cannot read \(address): \(message)")
            }
            return (output.stdout ?? []).map(Byte.init(_:))
        }
    }
}
