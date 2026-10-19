public import Institute_Architecture_Facts
public import Institute_Architecture_Model
public import Institute_Architecture_Validation
public import Institute_Model

extension Institute.Architecture.Index.Artifact {
    /// Refuses malformed, incompatible, or tampered canonical bytes.
    ///
    /// The supplied facts and report reconstruct the one graph this artifact
    /// is allowed to represent. A self-consistent digest is not enough: an
    /// adversary can recompute it after replacing an edge.
    public static func verify(
        _ rendered: Swift.String,
        facts: Institute.Architecture.Facts,
        validation: Institute.Architecture.Validator.Report
    ) throws(Error) {
        try verifyStructure(rendered)
        let expected = try Self(facts: facts, validation: validation)
        guard rendered == expected.rendered else { throw .malformed }
    }

    private static func verifyStructure(_ rendered: Swift.String) throws(Error) {
        let lines = rendered.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count >= 6 else { throw .malformed }
        let digest = Swift.String(lines[0])
        guard digest.hasPrefix("digest\t") else { throw .malformed }
        let claimed = Swift.String(digest.dropFirst("digest\t".count))
        let payload = lines.dropFirst().joined(separator: "\n")
        guard lines[1] == "schema\t\(schema)" else {
            throw .unsupportedSchema(Swift.String(lines[1]))
        }
        guard lines[2] == "version\t\(version)" else {
            throw .unsupportedSchema(Swift.String(lines[2]))
        }
        guard lines[3].hasPrefix("measurement\tcomplete\t") else { throw .malformed }
        guard lines[4].hasPrefix("index-digest\t") else { throw .malformed }
        guard lines[5] == "validation\tvalid" else { throw .malformed }
        let coverage = try coverage(line: Swift.String(lines[3]))
        let contents = try contents(lines: lines.dropFirst(6))
        guard
            coverage.measured == contents.entries.count,
            coverage.required == contents.entries.count
        else {
            throw .malformed
        }
        let index = Institute.Architecture.Index(entries: contents.entries)
        guard lines[4] == "index-digest\t\(index.digest)" else {
            throw .digestMismatch(
                expected: Swift.String(lines[4].dropFirst("index-digest\t".count)),
                actual: index.digest.description
            )
        }
        let canonicalCoverage = Institute.Architecture.Facts.Coverage(
            required: contents.entries.map(\.owner),
            measured: contents.entries.map(\.owner)
        )
        guard
            payload
                == Self.payload(
                    index: index,
                    edges: contents.edges,
                    coverage: canonicalCoverage
                )
        else { throw .malformed }
        let actual = Institute.Architecture.Index.Digest(text: payload).description
        guard claimed == actual else {
            throw .digestMismatch(expected: claimed, actual: actual)
        }
    }

    private static func coverage(
        line: Swift.String
    ) throws(Error) -> (measured: Swift.Int, required: Swift.Int) {
        let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
        guard fields.count == 3 else { throw .malformed }
        let counts = fields[2].split(separator: "/", omittingEmptySubsequences: false)
        guard
            counts.count == 2,
            let measured = Swift.Int(counts[0]),
            let required = Swift.Int(counts[1]),
            measured >= 0,
            required >= 0,
            measured == required
        else { throw .malformed }
        return (measured: measured, required: required)
    }

    private static func contents(
        lines: some Collection<Substring>
    ) throws(Error) -> (
        entries: [Institute.Architecture.Index.Entry],
        edges: [Institute.Architecture.Edge]
    ) {
        var entries: [Institute.Architecture.Index.Entry] = []
        var edges: [Institute.Architecture.Edge] = []
        var foundEdge = false
        for line in lines {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard let kind = fields.first else { throw .malformed }
            switch kind {
            case "entry":
                guard !foundEdge, let entry = entry(fields: fields) else { throw .malformed }
                entries.append(entry)

            case "edge":
                foundEdge = true
                guard let edge = edge(fields: fields) else { throw .malformed }
                edges.append(edge)

            default:
                throw .malformed
            }
        }
        guard
            entries.count == Swift.Set(entries.map(\.owner)).count,
            Institute.Architecture.Index(entries: entries).entries == entries,
            edges.sorted() == edges,
            edges.count == Swift.Set(edges).count
        else { throw .malformed }
        let owners = Swift.Set(entries.map(\.owner))
        guard edges.allSatisfy({ owners.contains($0.source) && owners.contains($0.destination) })
        else { throw .malformed }
        guard
            entries.allSatisfy { entry in
                entry.edgeCount == edges.filter { $0.source == entry.owner }.count
            }, entries.reduce(0, { $0 + $1.edgeCount }) == edges.count
        else { throw .malformed }
        return (entries: entries, edges: edges)
    }

    private static func entry(
        fields: [Substring]
    ) -> Institute.Architecture.Index.Entry? {
        guard
            fields.count == 7,
            let owner = owner(Swift.String(fields[1])),
            let layer = Institute.Architecture.Layer(name: Swift.String(fields[2])),
            Swift.String(fields[3])
                == Institute.Architecture.Concept.Identifier(owner: owner).description,
            let products = count(Swift.String(fields[4]), prefix: "products="),
            let targets = count(Swift.String(fields[5]), prefix: "targets="),
            let edges = count(Swift.String(fields[6]), prefix: "edges=")
        else { return nil }
        return .init(
            owner: owner,
            layer: layer,
            concept: .init(owner: owner),
            productCount: products,
            targetCount: targets,
            edgeCount: edges
        )
    }

    private static func edge(fields: [Substring]) -> Institute.Architecture.Edge? {
        guard
            fields.count == 4,
            let kind = Institute.Architecture.Edge.Kind.allCases.first(
                where: { $0.name == fields[1] }
            ),
            let source = owner(Swift.String(fields[2])),
            let destination = owner(Swift.String(fields[3]))
        else { return nil }
        return .init(source: source, destination: destination, kind: kind)
    }

    private static func owner(_ coordinate: Swift.String) -> Institute.Architecture.Owner? {
        .init(coordinate: coordinate)
    }

    private static func count(_ field: Swift.String, prefix: Swift.String) -> Swift.Int? {
        guard
            field.hasPrefix(prefix),
            let value = Swift.Int(field.dropFirst(prefix.count)),
            value >= 0
        else {
            return nil
        }
        return value
    }
}
