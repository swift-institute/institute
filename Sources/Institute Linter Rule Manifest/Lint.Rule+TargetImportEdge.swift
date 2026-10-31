public import Lint
internal import Linter_Rule_Scope
internal import SwiftParser
internal import SwiftSyntax

extension Lint.Rule {

    public static let `target import edge` = Lint.Rule(
        id: "target import edge",

        default: .warning,
        controls: [
            .init(
                id: "target import edge absent materialized sources",
                source: """
                    import PackageDescription

                    let package = Package(
                        name: "Fixture",
                        targets: [.target(name: "Fixture")]
                    )
                    """,
                path: "/Controls/TargetImportEdge/Package.swift",
                expectation: .clean
            )
        ],
        observe: Lint.Rule.measured { source, severity in
            packageTargetImportEdgeFindings(source: source, severity: severity)
        }
    )
}

package let packageTargetImportEdgeToolchainModules: Swift::Set<Swift::String> = [
    "Swift", "Testing", "XCTest", "Foundation", "FoundationEssentials",
    "Dispatch", "os", "Darwin", "Glibc", "Musl", "WinSDK", "Android",
    "Observation", "Synchronization", "Builtin", "CRT", "ucrt",
    "SwiftShims", "DistributedActors", "Distributed", "RegexBuilder",
    "StringProcessing", "CoreFoundation", "ObjectiveC", "simd", "Accelerate",
]

package func packageTargetImportEdgeNormalize(_ name: Swift::String) -> Swift::String {
    var out = ""
    out.reserveCapacity(name.count)
    for character in name {
        out.append(character == " " || character == "-" ? "_" : character)
    }
    return out
}

package func packageTargetImportEdgeFindings(
    source: borrowing Lint.Source.Parsed,
    severity: Diagnostic.Severity
) -> [Diagnostic.Record] {

    let runPath = Swift::String(describing: source.path)
    guard runPath == "Package.swift" || runPath.hasSuffix("/Package.swift") else { return [] }

    let filePath = source.file.filePath
    guard filePath.hasSuffix("/Package.swift") else { return [] }
    let root = Swift::String(filePath.dropLast("/Package.swift".count))
    guard Lint.Scope.File.isDirectory(root) else { return [] }

    let visitor = PackageTargetImportEdgeManifestVisitor()
    visitor.walk(source.tree)
    let manifest = visitor.manifest

    var dependencyManifestPaths: [Swift::String] = []
    var resolvedCount = 0
    for relative in manifest.pathDependencies {
        let candidate = root + "/" + relative + "/Package.swift"
        if Lint.Scope.File.isFile(candidate) {
            dependencyManifestPaths.append(candidate)
            resolvedCount += 1
        }
    }
    for url in manifest.urlDependencies {
        var trimmed = url
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        let parts = trimmed.split(separator: "/").map(Swift::String.init)
        let tail = parts.suffix(2)
        guard tail.count == 2, let organization = tail.first, var name = tail.last else { continue }
        if name.hasSuffix(".git") { name = Swift::String(name.dropLast(4)) }
        let candidate = root + "/../../" + organization + "/" + name + "/Package.swift"
        if Lint.Scope.File.isFile(candidate) {
            dependencyManifestPaths.append(candidate)
            resolvedCount += 1
        }
    }
    let declaredCount = manifest.pathDependencies.count + manifest.urlDependencies.count

    let unresolvableDependencies = declaredCount > resolvedCount

    var dependencyProducts: [Swift::String: Swift::Set<Swift::String>] = [:]
    for manifestPath in dependencyManifestPaths {
        guard let text = Lint.Scope.File.text(at: manifestPath) else { continue }
        let tree = Parser.parse(source: text)
        let dependencyVisitor = PackageTargetImportEdgeManifestVisitor()
        dependencyVisitor.walk(tree)
        for (product, members) in dependencyVisitor.manifest.products {
            dependencyProducts[product, default: []].formUnion(members)
        }
    }

    let samePackageTargets = Swift::Set(manifest.targets.map(\.name))
    var records: [Diagnostic.Record] = []

    for target in manifest.targets {
        let sourceDirectory: Swift::String
        if let explicit = target.explicitPath {
            sourceDirectory = root + "/" + explicit
        } else {
            let base = target.kind == .testTarget ? "Tests" : "Sources"
            sourceDirectory = root + "/" + base + "/" + target.name
        }
        guard Lint.Scope.File.isDirectory(sourceDirectory) else { continue }

        var allowed: Swift::Set<Swift::String> = [packageTargetImportEdgeNormalize(target.name)]
        for dependency in target.dependencies {
            switch dependency {
            case .target(let name):
                allowed.insert(packageTargetImportEdgeNormalize(name))

            case .product(let name):
                if let members = dependencyProducts[name] {
                    allowed.formUnion(members)
                } else {

                    allowed.insert(packageTargetImportEdgeNormalize(name))
                }

            case .byName(let name):
                if samePackageTargets.contains(name) {
                    allowed.insert(packageTargetImportEdgeNormalize(name))
                } else {
                    if let members = dependencyProducts[name] {
                        allowed.formUnion(members)
                    }
                    allowed.insert(packageTargetImportEdgeNormalize(name))
                }
            }
        }

        var sightings: [Swift::String: (Swift::String, Swift::Int)] = [:]
        for swiftFile in Lint.Scope.File.swiftFiles(under: sourceDirectory) {
            guard let text = Lint.Scope.File.text(at: swiftFile) else { continue }
            let tree = Parser.parse(source: text)
            let converter = SourceLocationConverter(fileName: swiftFile, tree: tree)
            let importVisitor = PackageTargetImportEdgeImportVisitor(converter: converter)
            importVisitor.walk(tree)
            var relative = swiftFile
            if relative.hasPrefix(root + "/") {
                relative = Swift::String(relative.dropFirst(root.count + 1))
            }
            for (module, line) in importVisitor.imports where sightings[module] == nil {
                sightings[module] = (relative, line)
            }
        }

        for module in sightings.keys.sorted() {
            guard let (relative, line) = sightings[module] else { continue }
            if packageTargetImportEdgeToolchainModules.contains(module) { continue }
            if module.hasPrefix("_") { continue }
            if allowed.contains(module) { continue }
            if unresolvableDependencies { continue }
            let location = source.converter.location(for: target.namePosition)
            records.append(
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.file.fileID,
                        filePath: source.file.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "target import edge",
                    message: "[target import edge]: \(relative):\(line): target "
                        + "'\(target.name)' imports '\(module)' without a declared "
                        + "dependency edge ([TARGET-IMPORT-EDGE]: transitive-build "
                        + "riding is a scheduling race; declare the target/product "
                        + "dependency)"
                )
            )
        }
    }
    return records
}
