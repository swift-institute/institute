public import Institute_Model

extension Institute.CI.Timeout {
    public enum Error: Swift.Error, Equatable {
        /// The value is not a whole number of minutes from 1 to 360.
        case invalid(String)
    }
}
