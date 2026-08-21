public import File_System
public import Institute_Inventory
public import Institute_Model
public import JSON
public import Xcode_Workspace

extension Institute {
    public enum Xcode {}
}

extension Institute.Xcode {
    public static let bundleName = "institute interim.xcworkspace"

    public static func specification(
        _ repositories: [Institute.Repository]
    ) throws(Institute.Error) -> Institute.Workspace.Specification {
        var members: [Institute.Workspace.Member] = [
            .init(location: "group:.", role: .control(.application)),
            .init(location: "group:../institute", role: .control(.institute)),
            .init(
                location: "group:../institute-continuous-integration",
                role: .control(.continuousIntegration)
            ),
        ]
        var locations = Swift.Set(members.map(\.location))
        for repository in repositories {
            guard let key = Institute.Repository.Key(
                identity: "\(repository.organization)/\(repository.name)"
            ) else {
                throw .configuration("workspace repository identity is invalid: \(repository.name)")
            }
            let location = "group:../\(Institute.Layout.reference(for: repository))"
            guard locations.insert(location).inserted else {
                throw .configuration("workspace member is declared more than once: \(location)")
            }
            members.append(.init(location: location, role: .subject(key)))
        }
        return .init(members: members)
    }

    public static func document(
        _ specification: Institute.Workspace.Specification
    ) throws(Institute.Error) -> Xcode_Workspace.Xcode.Workspace {
        var references: [Xcode_Workspace.Xcode.Workspace.Reference] = []
        for member in specification.members {
            guard let location = Xcode_Workspace.Xcode.Workspace.Location(
                rawValue: member.location
            ) else {
                throw .configuration("invalid workspace member location: \(member.location)")
            }
            references.append(.init(location: location))
        }
        return .init(references: references)
    }

    public static func render(
        _ specification: Institute.Workspace.Specification
    ) throws(Institute.Error) -> Swift.String {
        try document(specification).xml + "\n"
    }

    public static func bundle(at root: File.Directory) -> File.Directory {
        root[directory: "institute interim.xcworkspace"]
    }

    public static func path(at root: File.Directory) -> File {
        bundle(at: root)[file: "contents.xcworkspacedata"]
    }

    public static func specificationPath(at root: File.Directory) -> File {
        bundle(at: root)[directory: "xcshareddata"][file: "Institute.workspace.json"]
    }

    public static func contents(at root: File.Directory) -> Swift.String? {
        read(path(at: root))
    }

    public static func specificationContents(at root: File.Directory) -> Swift.String? {
        read(specificationPath(at: root))
    }

    public static func current(
        _ specification: Institute.Workspace.Specification,
        at root: File.Directory
    ) -> Swift.Bool {
        guard let rendered = try? render(specification) else { return false }
        return contents(at: root) == rendered
            && specificationContents(at: root)
                == specification.jsonString(sortKeys: true) + "\n"
    }

    public static func write(
        _ specification: Institute.Workspace.Specification,
        at root: File.Directory
    ) throws(Institute.Error) {
        let bundle = bundle(at: root)
        let shared = bundle[directory: "xcshareddata"]
        do throws(File.System.Create.Directory.Error) {
            try shared.create.recursive()
        } catch {
            throw .filesystem("cannot create \(shared): \(error)")
        }
        do throws(File.System.Write.Atomic.Error) {
            try path(at: root).write.atomic(render(specification))
            try specificationPath(at: root).write.atomic(
                specification.jsonString(sortKeys: true) + "\n"
            )
        } catch {
            throw .filesystem("cannot write \(bundle): \(error)")
        }
    }

    private static func read(_ file: File) -> Swift.String? {
        do throws(Either<File.System.Read.Full.Error, Never>) {
            return try file.read.full { bytes in
                var storage = [Byte]()
                storage.reserveCapacity(bytes.count)
                for index in bytes.indices { storage.append(bytes[index]) }
                return Swift.String(decoding: storage, as: Swift.UTF8.self)
            }
        } catch {
            return nil
        }
    }
}
