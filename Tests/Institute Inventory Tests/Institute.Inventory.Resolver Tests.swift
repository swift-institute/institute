import Testing

@testable import Institute_Inventory

@Suite
struct `Institute.Inventory.Resolver Tests` {
    // Targets: 0 Picture, 1 App (sees 0), 2 Other (declares Picture.Color too), 3 Coder.
    let resolver = Institute.Inventory.Resolver(
        declarations: [
            (["Picture"], 0),
            (["Picture", "Encoded"], 0),
            (["Picture", "Encoded", "Pixel"], 0),
            (["Picture", "Color"], 0),
            (["Picture", "Color"], 2),
            (["Swift", "String", "Counted"], 0),
            (["String", "Coder"], 3),
            (["App"], 1),
            (["App", "Pixel"], 1),
            (["Coder"], 3),
        ],
        modules: ["Swift", "Picture_Module", "Coder"]
    )

    func paths(
        _ chain: [Swift.String],
        from: [Swift.String] = [],
        visible: Swift.Set<Swift.Int>
    ) -> [Swift.String] {
        resolver.resolve(chain: chain, from: from, visible: visible).candidates.map { "\($0.path)@\($0.target)" }
    }

    @Test
    func `a chain resolves to its longest declared prefix`() {
        #expect(paths(["Picture", "Encoded", "Pixel"], visible: [0, 1]) == ["Picture.Encoded.Pixel@0"])
        #expect(paths(["Picture", "Encoded", "Undeclared"], visible: [0, 1]) == ["Picture.Encoded@0"])
    }

    @Test
    func `an enclosing scope shadows the top level`() {
        #expect(paths(["Pixel"], from: ["App"], visible: [0, 1]) == ["App.Pixel@1"])
        #expect(paths(["Pixel"], from: ["Picture", "Encoded"], visible: [0, 1]) == ["Picture.Encoded.Pixel@0"])
        #expect(paths(["Pixel"], visible: [0, 1]).isEmpty)
    }

    @Test
    func `only visible targets are candidates`() {
        #expect(paths(["App"], visible: [0]).isEmpty)
        #expect(paths(["App"], visible: [1]) == ["App@1"])
    }

    @Test
    func `the same path in two visible targets is ambiguous`() {
        let resolution = resolver.resolve(chain: ["Picture", "Color"], from: [], visible: [0, 2])
        #expect(resolution.candidates.map(\.target) == [0, 2])
        #expect(resolution.ambiguous)
        #expect(!resolver.resolve(chain: ["Picture", "Color"], from: [], visible: [0]).ambiguous)
    }

    @Test
    func `a leading module name that is not a type is dropped`() {
        #expect(paths(["Swift", "String", "Counted"], visible: [0]) == ["Swift.String.Counted@0"])
        #expect(paths(["String", "Counted"], visible: [0]) == ["Swift.String.Counted@0"])
        #expect(paths(["Swift", "String", "Coder"], visible: [3]) == ["String.Coder@3"])
        #expect(paths(["Coder"], visible: [3]) == ["Coder@3"])
        #expect(paths(["Swift", "Int"], visible: [0, 3]).isEmpty)
    }

    @Test
    func `Self names the enclosing type and generic parameters stay unresolved`() {
        #expect(paths(["Self", "Pixel"], from: ["Picture", "Encoded"], visible: [0]) == ["Picture.Encoded.Pixel@0"])
        #expect(resolver.resolve(chain: ["Picture"], from: [], generic: true, visible: [0]).candidates.isEmpty)
    }
}
