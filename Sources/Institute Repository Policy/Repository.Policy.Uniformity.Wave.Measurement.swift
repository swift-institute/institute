extension Repository.Policy.Uniformity.Wave {
    enum Measurement: Sendable {
        case excluded(String)
        case subject(Subject)
    }
}
