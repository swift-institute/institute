public import Institute_Model

extension Institute.Repository.Policy.Caller.Wave {
    enum Measurement: Sendable {
        case excluded(String)
        case missingCaller(String)
        case subject(Subject)
    }
}
