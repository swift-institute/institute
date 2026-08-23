public import Institute_Source_Policy
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
