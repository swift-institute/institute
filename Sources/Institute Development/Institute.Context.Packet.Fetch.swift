internal import Institute_Inventory
public import Institute_Model

extension Institute.Context.Packet {
  public enum Fetch<Value: Sendable>: Sendable {
    case available(Value)
    case unavailable(Swift.String)
    case malformed(Swift.String)
    case unmeasured(Swift.String)
  }
}
