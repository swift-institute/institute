public import Institute_Inventory
public import Institute_Model
public import Xcode_Workspace

extension Institute.Xcode {
    public static func integration(
        _ repositories: [Institute.Repository]
    ) throws(Institute.Error) -> Institute.Workspace.Specification {
        let subjects = try specification(repositories)
        let controls = integrationControls.map { control in
            Institute.Workspace.Member(
                location: control.location,
                role: .control(control)
            )
        }
        let members = controls + subjects.members
        guard Set(members.map(\.location)).count == members.count else {
            throw .configuration("workspace integration contains duplicate locations")
        }
        return .init(members: members)
    }

    public static func integration(
        _ workspace: Xcode_Workspace.Xcode.Workspace,
        repositories: [Institute.Repository]
    ) throws(Institute.Error) -> Institute.Workspace.Specification {
        let available = try integration(repositories)
        let locations = locations(in: workspace.references)
        guard !locations.isEmpty else {
            throw .configuration("workspace contains no package references")
        }
        guard Set(locations).count == locations.count else {
            throw .configuration("workspace contains duplicate package references")
        }

        var members = [Institute.Workspace.Member]()
        members.reserveCapacity(locations.count)
        for location in locations {
            guard let member = available.members.first(where: { $0.location == location }) else {
                throw .configuration("workspace reference is outside Institute inventory: \(location)")
            }
            members.append(member)
        }
        return .init(members: members)
    }

    private static func locations(
        in references: [Xcode_Workspace.Xcode.Workspace.Reference]
    ) -> [Swift.String] {
        var result = [Swift.String]()
        for reference in references {
            switch reference {
            case .file(let location):
                result.append(location.rawValue)
            case .group(let group):
                result.append(contentsOf: locations(in: group.references))
            }
        }
        return result
    }

    private static let integrationControls: [Institute.Workspace.Control] = [
        .institute,
        .application,
    ]
}

extension Institute.Workspace.Control {
    fileprivate var location: Swift.String {
        switch self {
        case .application:
            "group:."
        case .institute:
            "group:../institute"
        case .continuousIntegration:
            "group:../institute-continuous-integration"
        }
    }
}
