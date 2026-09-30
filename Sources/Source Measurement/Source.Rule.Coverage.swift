extension Source.Rule {
  public enum Coverage: Hashable, Sendable {
    case measured
    case unmeasured(Source.Reason)
  }
}
