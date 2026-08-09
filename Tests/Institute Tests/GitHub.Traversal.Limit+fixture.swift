@testable import Institute_Model
@testable import Institute_Inventory
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Lint
@testable import Institute_Pages
@testable import Institute_Doctor
@testable import Institute_Conversion
@testable import Institute_Instruments

import GitHub

extension GitHub.Page.Number {
    init(fixture value: UInt) {
        guard let number = Self(rawValue: value) else {
            preconditionFailure("Invalid fixture page number")
        }
        self = number
    }
}

extension GitHub.Organization.Repositories.Traversal.Limit {
    init(fixture pages: UInt, items: UInt) {
        guard
            let pageLimit = Pages(rawValue: pages),
            let itemLimit = Items(rawValue: items)
        else { preconditionFailure("Invalid fixture traversal limit") }
        self.init(pages: pageLimit, items: itemLimit)
    }
}
