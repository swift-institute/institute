import Environment
public import Institute_Model
import Institute_Source_Policy
public import Source_Profile

extension Institute.Source {
    public struct Acquisition: Sendable {
        let process: Source_Measurement.Source.Engine.Process
        /// The directories a toolchain tool is looked for in, in order: the
        /// entries of `PATH`.
        let search: [Swift.String]

        public init(process: Source_Measurement.Source.Engine.Process) {
            self.init(
                process: process,
                search: (Environment.read("PATH") ?? "").split(separator: ":").map(Swift.String.init)
            )
        }

        init(process: Source_Measurement.Source.Engine.Process, search: [Swift.String]) {
            self.process = process
            self.search = search
        }
    }
}
