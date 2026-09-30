internal import Tagged

extension Institute.Workspace.Control {
    public var repository: Institute.Repository.Key {
        switch self {
        case .application:
            .init(owner: .init("swift-institute"), name: .init("institute-application"))
        case .institute:
            .init(owner: .init("swift-institute"), name: .init("institute"))
        case .continuousIntegration:
            .init(
                owner: .init("swift-institute"),
                name: .init("institute-continuous-integration")
            )
        case .linter:
            .init(owner: .init("swift-foundations"), name: .init("swift-linter"))
        }
    }
}
