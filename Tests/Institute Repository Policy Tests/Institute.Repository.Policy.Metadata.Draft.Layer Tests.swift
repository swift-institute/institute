import Institute_Model
import Testing

@testable import Institute_Repository_Policy

@Suite struct `Institute.Repository.Policy.Metadata.Draft layer topic` {
    @Test func `every standards-layer organization carries the standards topic`() {
        for organization in Institute.Organization.allCases where organization.layer == .standards {
            #expect(Institute.Repository.Policy.Metadata.Draft.layer(of: organization.rawValue) == "standards")
        }
    }

    @Test func `the other layers keep their topics`() {
        #expect(Institute.Repository.Policy.Metadata.Draft.layer(of: "swift-atoms") == "primitives")
        #expect(Institute.Repository.Policy.Metadata.Draft.layer(of: "swift-molecules") == "primitives")
        #expect(Institute.Repository.Policy.Metadata.Draft.layer(of: "swift-compositions") == "foundations")
        #expect(Institute.Repository.Policy.Metadata.Draft.layer(of: "swift-institute") == "")
        #expect(Institute.Repository.Policy.Metadata.Draft.layer(of: "pointfreeco") == "")
    }
}
