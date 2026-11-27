internal import Institute_Model

extension Institute.Inventory.Assembly {
    /// The tables about members: what is declared and which names code uses.
    struct Surface {
        let assembly: Institute.Inventory.Assembly
    }
}

extension Institute.Inventory.Assembly.Surface {
    /// `members.json`: one row per member, files in the order of `types.json`.
    var declared: Institute.Inventory.Table {
        let (members, targets) = (assembly.members, assembly.targets)
        let sorted = assembly.files.sorted { left, right in
            (members[targets[left.0].package].path, targets[left.0].name, left.1)
                < (members[targets[right.0].package].path, targets[right.0].name, right.1)
        }
        var rows: [Institute.Inventory.Table.Row] = []
        for (target, name, facts) in sorted {
            for member in facts?.members ?? [] {
                rows.append(
                    assembly.location(target) + [
                        ("owner", .text(member.owner.joined(separator: "."))),
                        ("in_extension", .flag(member.extended)),
                        ("kind", .text(member.kind)),
                        ("name", .text(member.name)),
                        ("access", .text(member.access)),
                        ("static", .flag(member.shared)),
                        ("mutating", .flag(member.mutating)),
                        ("async", .flag(member.async)),
                        ("throws", .text(member.thrown)),
                        ("generic_parameters", .text(member.generics.joined(separator: ","))),
                        ("parameters", .number(member.parameters.count)),
                        ("parameter_types", .text(member.parameters.joined(separator: ", "))),
                        ("result", .text(member.result)),
                        ("stored", .flag(member.stored)),
                        ("condition", .text(member.condition)),
                        ("file", .text(assembly.file(target, name))),
                        ("line", .number(member.line)),
                    ]
                )
            }
        }
        return .init(name: "members", rows: rows)
    }

    /// `member_uses.json`: how often each target writes each member name.
    var used: Institute.Inventory.Table {
        var counts = [[Swift.String: Swift.Int]](repeating: [:], count: assembly.targets.count)
        for (target, _, facts) in assembly.files {
            for (name, count) in facts?.uses ?? [:] { counts[target][name, default: 0] += count }
        }
        var rows: [Institute.Inventory.Table.Row] = []
        for (target, names) in counts.enumerated() {
            for (name, count) in names.sorted(by: { $0.key < $1.key }) {
                rows.append(assembly.location(target) + [("name", .text(name)), ("count", .number(count))])
            }
        }
        return .init(name: "member_uses", rows: rows)
    }
}
