import Byte
import Institute_Model
import Process

extension Institute.Planner {
    /// Public GitHub content, read through `curl` without any credential, so
    /// a developer machine and a clean hosted runner read it the same way.
    enum Curl {
        /// The response body at `address`; a non-success status is refused.
        static func get(_ address: Swift.String) throws(Institute.Planner.Error) -> [Byte] {
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
