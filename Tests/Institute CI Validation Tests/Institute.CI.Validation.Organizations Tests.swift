import Institute_Model
import Testing

@testable import Institute_CI_Validation

/// The validators that scope a rule to the Institute's organizations take
/// them from `Institute.Organization`, not from a list of their own.
@Suite struct `Institute.CI.Validation organizations` {
    @Test func `branch pins judge every Institute organization`() {
        let names = Institute.CI.Validation.BranchPins().organizations.names
        #expect(names == Set(Institute.Organization.allCases.map(\.rawValue)))
        #expect(names.contains("swift-bipm"))
        #expect(!names.contains("swift-primitives"))
    }

    @Test func `the sub-organizations are the standards layer below swift-standards`() {
        let subOrganizations = Institute.CI.Validation.SubOrgWrappers.subOrganizations
        #expect(subOrganizations.count == 14)
        #expect(subOrganizations.contains("swift-bipm"))
        #expect(subOrganizations.contains("swift-arm-ltd"))
        #expect(!subOrganizations.contains("swift-standards"))
        #expect(!subOrganizations.contains("swift-atoms"))
    }
}
