public import File_System
public import Institute_Model
public import Institute_Source_Profile
public import Institute_Source_Workspace
public import JSON
public import Process
public import Source_Execution
public import Source_Measurement
public import Source_Profile
public import Source_Repair
public import Source_Report

extension Institute.Source {
  /// The executable source-quality capability. It deliberately has no build
  /// coordinator dependency: measuring source is independent of compiling it.
  public struct Application: Sendable {
    public let process: Source_Measurement.Source.Engine.Process

    public init(timeout: Duration = .seconds(300)) {
      self.process = .init { executable, arguments, directory, environment in
        do throws(Process.Error) {
          let output = try Process.Spawn.run(
            .init(
              executable: executable,
              arguments: arguments,
              environment: environment.isEmpty ? nil : environment,
              stdin: .pipe,
              stdout: .pipe,
              stderr: .pipe,
              workingDirectory: directory,
              timeout: timeout
            )
          )
          let status: Swift.Int32
          switch output.status {
          case .exited(let code): status = code
          case .signaled(let signal), .stopped(let signal): status = 128 + signal
          }
          return .init(
            status: status,
            output: Swift.String(decoding: output.stdout ?? [], as: Swift.UTF8.self),
            diagnostics: Swift.String(
              decoding: output.stderr ?? [],
              as: Swift.UTF8.self
            )
          )
        } catch {
          return .init(
            status: 127,
            output: "",
            diagnostics: "cannot execute \(executable): \(error)"
          )
        }
      }
    }
  }
}
