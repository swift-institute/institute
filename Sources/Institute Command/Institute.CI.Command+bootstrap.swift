import Byte
import Institute_CI_Contract
public import Institute_CI_Model
public import Institute_Model
import JSON

import struct Swift.String

extension Institute.CI.Command {
    // MARK: - bootstrap

    static func identityJSON(
        _ identity: Institute.CI.Bootstrap.Identity
    ) -> JSON {
        [
            "workspaceRevision": identity.workspaceRevision.json,
            "sourcesRevision": identity.sourcesRevision.json,
            "toolchain": identity.toolchain.json,
            "operatingSystem": identity.operatingSystem.json,
            "architecture": identity.architecture.json,
            "provisioning": identity.provisioning.sorted().json,
        ]
    }

    static func bootstrap(_ verb: Verb, _ rest: [Swift.String]) {
        let identity = Institute.CI.Bootstrap.Identity(
            workspaceRevision: value("--workspace-revision", in: rest),
            sourcesRevision: value("--sources-revision", in: rest),
            toolchain: value("--toolchain", in: rest),
            operatingSystem: value("--os", in: rest),
            architecture: value("--arch", in: rest),
            provisioning: value("--provisioning", in: rest)
                .split(separator: ",").map(Swift.String.init)
        )
        do throws(Institute.CI.Bootstrap.Identity.ValidationError) {
            try identity.validate()
        } catch {
            refuse("bootstrap identity refused: \(error)")
        }

        switch verb {
        case .bootstrapIdentity:
            emit([
                "workspaceRevision": identity.workspaceRevision.json,
                "sourcesRevision": identity.sourcesRevision.json,
                "toolchain": identity.toolchain.json,
                "operatingSystem": identity.operatingSystem.json,
                "architecture": identity.architecture.json,
                "provisioning": identity.provisioning.sorted().json,
                "key": identity.digest.json,
            ])

        case .bootstrapManifest:
            let root = value("--root", in: rest)
            var executables: [JSON] = []
            for path in value("--executables", in: rest)
                .split(separator: ",").map(Swift.String.init)
            {
                guard let bytes = contents(atPath: root + "/" + path)
                else { refuse("bootstrap-manifest: unreadable executable \(path)") }
                let executable = Institute.CI.Bootstrap.Manifest.Executable(
                    path: path,
                    bytes: bytes
                )
                executables.append([
                    "path": executable.path.json,
                    "digest": executable.digest.json,
                ])
            }
            if executables.isEmpty { refuse("bootstrap-manifest: no executables") }
            emit([
                "identity": identityJSON(identity),
                "key": identity.digest.json,
                "executables": .array(executables),
                "producerRun": value("--producer-run", in: rest).json,
            ])

        case .bootstrapVerify:
            let root = value("--root", in: rest)
            guard let manifestText = text(atPath: value("--manifest", in: rest))
            else { refuse("bootstrap-verify: unreadable manifest") }
            let object = decoded(manifestText, "bootstrap-verify manifest")
            guard
                let identityObject = object["identity"]?.dictionary,
                let key = Swift.String(object["key"]),
                let executableValues = object["executables"]?.array,
                let producerRun = Swift.String(object["producerRun"])
            else { refuse("bootstrap-verify: malformed manifest") }

            let recorded = Institute.CI.Bootstrap.Identity(
                workspaceRevision: Swift.String(identityObject["workspaceRevision"] ?? .null),
                sourcesRevision: Swift.String(identityObject["sourcesRevision"] ?? .null),
                toolchain: Swift.String(identityObject["toolchain"] ?? .null),
                operatingSystem: Swift.String(identityObject["operatingSystem"] ?? .null),
                architecture: Swift.String(identityObject["architecture"] ?? .null),
                provisioning: (identityObject["provisioning"]?.array ?? [])
                    .map { Swift.String($0) }
            )
            let manifest = Institute.CI.Bootstrap.Manifest(
                identity: recorded,
                key: key,
                executables: executableValues.map {
                    .init(
                        path: Swift.String($0["path"]),
                        digest: Swift.String($0["digest"])
                    )
                },
                producerRun: producerRun
            )
            do throws(Institute.CI.Bootstrap.Manifest.VerificationError) {
                try manifest.verify(against: identity) { path in
                    contents(atPath: root + "/" + path)
                }
            } catch {
                refuse("bootstrap cache entry refused (fail closed): \(error)")
            }
            print(
                """
                verified: key \(identity.digest), \
                \(executableValues.count) executable(s), producer run \(producerRun)
                """
            )

        case .control, .packageCommand, .source:
            refuse("unreachable")
        }
    }
}
