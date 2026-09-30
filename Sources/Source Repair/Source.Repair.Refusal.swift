extension Source.Repair {
  public struct Refusal: Sendable, JSON.Serializable {
    public let reason: Source.Reason

    public init(_ reason: Source.Reason) { self.reason = reason }

    public static func serialize(_ value: Self) -> JSON { value.reason.json }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
      try Self(Source.Reason(json: json))
    }
  }
}
