public import Institute_Continuous_Integration_Source
public import Institute_Model
public import Source_Profile

extension Institute.Source {
  public struct Acquisition: Sendable {
    let process: Source_Measurement.Source.Engine.Process

    public init(process: Source_Measurement.Source.Engine.Process) {
      self.process = process
    }
  }
}
