public import Institute_Continuous_Integration_Source
public import Institute_Model
public import Source_Profile

extension Institute.Source {
    public struct Acquisition: Sendable {
        let process: SourceDomain.Engine.Process

        public init(process: SourceDomain.Engine.Process) {
            self.process = process
        }
    }
}
