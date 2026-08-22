internal import Institute_Model
internal import Package_Manager
internal import Source_Measurement

extension Institute.Xcode.Acquisition {
    struct Observation: Sendable {
        struct Payload: Sendable {
            let catalog: Package.Manager.Catalog
            let sources: [Source.Artifact]
        }

        let index: Swift.Int
        let member: Institute.Workspace.Member
        let reference: Swift.String
        let duration: Swift.Duration
        let result: Swift.Result<Payload, Institute.Error>
    }
}
