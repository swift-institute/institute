public import Institute_Model

extension Institute.Repository.Policy.Automation {
    /// The kinds of coordinate a row of the automation names, as the FT1 census schema spells them.
    public enum Kind: String, Sendable, Equatable, CaseIterable {
        case file
        case runBlock = "run-block"
        case expression
        case usesEdge = "uses-edge"
        case commandReference = "command-reference"
        case family
    }
}
