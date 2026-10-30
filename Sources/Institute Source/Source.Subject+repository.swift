public import Source_Measurement

extension Source_Measurement.Source.Subject {
    package var repository: Swift.String {
        Swift.String(identity.prefix { $0 != "@" })
    }
}
