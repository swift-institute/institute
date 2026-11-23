extension Source.Subject {
    public var binding: Binding {
        let bytes = jsonString(sortKeys: true).utf8.map(Byte.init(_:))
        return .init(identity: identity, digest: NIST.FIPS.`180`.`4`.SHA256.digest(bytes))
    }
}
