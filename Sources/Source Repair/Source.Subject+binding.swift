extension Source.Subject {
  public var binding: Binding {
    let bytes = jsonString(sortKeys: true).utf8.map(Byte.init(_:))
    return .init(identity: identity, digest: FIPS_180_4.SHA256.digest(bytes).hex)
  }
}
