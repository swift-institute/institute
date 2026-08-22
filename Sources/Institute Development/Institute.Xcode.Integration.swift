public import Institute_Inventory
public import Institute_Model

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
