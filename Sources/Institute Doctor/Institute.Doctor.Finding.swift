public import Institute_Development
public import Institute_Inventory
public import Institute_Lint
public import Institute_Model
public import Institute_Pages

extension Institute.Doctor {
  /// One measured problem, produced by a check's evaluation of one subject.
  public struct Finding: Equatable, Sendable {
    public let severity: Severity
    public let message: Swift.String

    public init(severity: Severity, message: Swift.String) {
      self.severity = severity
      self.message = message
    }
  }
}
