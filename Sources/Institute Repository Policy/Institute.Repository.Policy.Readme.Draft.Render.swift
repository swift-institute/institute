public import Institute_Model

extension Institute.Repository.Policy.Readme.Draft {
    public struct Render: Sendable {
        public init() {}
    }
}

extension Institute.Repository.Policy.Readme.Draft.Render {
    public func callAsFunction(_ draft: Institute.Repository.Policy.Readme.Draft) -> Swift.String {
        let owner = draft.repository.split(separator: "/").first.map(Swift.String.init) ?? ""
        let name = draft.repository.split(separator: "/").last.map(Swift.String.init) ?? draft.repository
        var sections: [Swift.String] = ["# \(name)", draft.description]
        if let layer = Self.layer(of: owner) {
            sections.append(
                "Part of [\(owner)](https://github.com/\(owner)), \(layer) of the "
                    + "[Swift Institute](https://github.com/swift-institute)."
            )
        }
        if !draft.products.isEmpty {
            let rows = draft.products.map { product in
                "| `\(product.name)` | \(product.targets.map { "`\($0)`" }.joined(separator: ", ")) |"
            }
            sections.append((["## Products", "", "| Product | Targets |", "|---|---|"] + rows).joined(separator: "\n"))
        }
        if !draft.traits.isEmpty {
            sections.append(
                "## Traits\n\n" + draft.traits.map { "`\($0)`" }.joined(separator: ", ") + ". "
                    + (draft.defaultTraits.isEmpty
                        ? "None is enabled by default."
                        : "Enabled by default: " + draft.defaultTraits.map { "`\($0)`" }.joined(separator: ", ") + ".")
            )
        }
        let product = draft.products.first?.name ?? name
        sections.append(
            """
            ## Installation

            ```swift
            dependencies: [
                .package(url: "https://github.com/\(draft.repository).git", branch: "main")
            ]
            ```

            ```swift
            .target(
                name: "YourTarget",
                dependencies: [
                    .product(name: "\(product)", package: "\(name)")
                ]
            )
            ```
            """
        )
        if !draft.errors.isEmpty {
            sections.append(
                "## Error Handling\n\nPublic operations throw typed errors declared in this package: "
                    + draft.errors.map { "`\($0)`" }.joined(separator: ", ") + "."
            )
        }
        sections.append("## License\n\n\(draft.license). See [LICENSE.md](LICENSE.md).")
        return sections.joined(separator: "\n\n") + "\n"
    }

    static func layer(of owner: Swift.String) -> Swift.String? {
        switch owner {
        case "swift-atoms": "layer 1 (what must exist)"
        case "swift-molecules": "layer 2 (what is built from atoms alone)"
        case "swift-compositions": "layer 4 (composed building blocks)"
        case "swift-standards", "swift-ietf", "swift-iso", "swift-w3c", "swift-whatwg", "swift-ieee", "swift-iec",
            "swift-ecma", "swift-incits", "swift-bipm", "swift-linux-foundation", "swift-arm-ltd", "swift-intel",
            "swift-riscv", "swift-microsoft":
            "layer 3 (specification implementations)"
        default: nil
        }
    }
}
