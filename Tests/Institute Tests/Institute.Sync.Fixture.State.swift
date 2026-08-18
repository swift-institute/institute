import Foundation
import Git_Foundation

@testable import Institute_Conversion
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Doctor
@testable import Institute_Instruments
@testable import Institute_Inventory
@testable import Institute_Lint
@testable import Institute_Model
@testable import Institute_Pages

extension Institute.Sync.Fixture {
    struct State: Equatable {
        let head: Git.Object.ID
        let origin: Git.Object.ID
        let fetch: Data?
        let status: [Git.Status.Entry]
        let workspace: Data?
        let ledger: Data?
        let canonical: [Swift.String]
        let legacy: [Swift.String]
    }
}
