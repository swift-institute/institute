public import File_System
public import Institute_Model
internal import JSON

extension Institute.Xcode {
    /// The complete, pre-rendered publication transaction for generated Xcode state.
    public struct Publication: Sendable {
        public let documents: [Document]

        public init(documents: [Document]) throws(Institute.Error) {
            let paths = documents.map { $0.file.description }
            guard Set(paths).count == paths.count else {
                throw .configuration("Xcode publication contains duplicate destinations")
            }
            self.documents = documents
        }
    }
}

extension Institute.Xcode.Publication {
    public func current(client: Client = .live) throws(Institute.Error) -> Swift.Bool {
        for document in documents {
            guard try client.read(document.file) == document.contents else { return false }
        }
        return true
    }

    public static func plan(
        specification: Institute.Workspace.Specification,
        catalog: Institute.Xcode.Catalog,
        scheme: Institute.Xcode.Scheme.Plan,
        at root: Institute.Root
    ) throws(Institute.Error) -> (
        publication: Self,
        receipt: Institute.Workspace.Materialization.Receipt
    ) {
        let workspaceContents = try Institute.Xcode.render(specification)
        let membershipContents = specification.jsonString(sortKeys: true) + "\n"
        let schemeContents = Institute.Xcode.Scheme.render(scheme)
        guard let toolchain = catalog.entries.first?.toolchain else {
            throw .configuration("cannot publish an empty target catalog")
        }
        let input = Institute.Workspace.Materialization.Input(
            toolchain: toolchain,
            packages: catalog.entries.map { entry in
                .init(
                    member: entry.member,
                    reference: entry.reference,
                    manifest: entry.manifest,
                    sources: entry.sources
                )
            }
        )
        let testables = Institute.Workspace.Materialization.Testables(
            values: scheme.testables.map { .init(reference: $0.reference, name: $0.target) }
        )
        let receipt = Institute.Workspace.Materialization.Receipt(
            input: input,
            artifacts: [
                .init(
                    name: "workspace",
                    path: "\(Institute.Xcode.bundleName)/contents.xcworkspacedata",
                    digest: Institute.Workspace.Materialization.digest(workspaceContents)
                ),
                .init(
                    name: "membership",
                    path: "\(Institute.Xcode.bundleName)/xcshareddata/Institute.workspace.json",
                    digest: Institute.Workspace.Materialization.digest(membershipContents)
                ),
                .init(
                    name: "scheme",
                    path:
                        "\(Institute.Xcode.bundleName)/xcshareddata/xcschemes/"
                        + "\(Institute.Xcode.Scheme.name).xcscheme",
                    digest: Institute.Workspace.Materialization.digest(schemeContents)
                ),
            ],
            buildables: scheme.buildables.map { .init(reference: $0.reference, name: $0.target) },
            testables: testables
        )
        let receiptContents = receipt.jsonString(sortKeys: true) + "\n"
        return (
            publication: try .init(
                documents: [
                    .init(
                        file: Institute.Xcode.path(at: root.checkout),
                        contents: workspaceContents
                    ),
                    .init(
                        file: Institute.Xcode.specificationPath(at: root.checkout),
                        contents: membershipContents
                    ),
                    .init(
                        file: Institute.Xcode.Scheme.path(at: root.checkout),
                        contents: schemeContents
                    ),
                    .init(
                        file: Institute.Workspace.Materialization.receiptPath(at: root),
                        contents: receiptContents
                    ),
                ]
            ),
            receipt: receipt
        )
    }

    /// Publishes every generated document as one recoverable transaction.
    /// All preimages are captured before the first write; any failure restores
    /// every destination to its exact prior bytes (or absence).
    public func apply(client: Client = .live) throws(Institute.Error) {
        var preimages = [Swift.String?]()
        preimages.reserveCapacity(documents.count)
        for document in documents {
            preimages.append(try client.read(document.file))
        }

        do {
            for document in documents {
                try client.write(document.file, document.contents)
            }
        } catch {
            let publicationError = "cannot publish generated Xcode state: \(error)"
            do {
                for (document, preimage) in zip(documents, preimages).reversed() {
                    if let preimage {
                        try client.write(document.file, preimage)
                    } else {
                        try client.delete(document.file)
                    }
                }
            } catch {
                throw .filesystem("\(publicationError); rollback failed: \(error)")
            }
            throw .filesystem(publicationError)
        }
    }

}
