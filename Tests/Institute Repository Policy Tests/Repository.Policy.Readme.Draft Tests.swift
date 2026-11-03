public import Institute_Model
import Institute_Repository_Policy
import Testing

extension Institute.Repository.Policy.Readme.Draft {
    @Suite
    struct Unit {
        typealias Draft = Institute.Repository.Policy.Readme.Draft

        @Test
        func `a layer package renders its layer, products, traits, installation, errors and license in that order`() {
            let draft = Draft(
                repository: "swift-molecules/swift-cache",
                description: "A compute-if-absent async cache.",
                products: [.init(name: "Cache", targets: ["Cache", "Cache Core"])],
                traits: ["Effect"],
                defaultTraits: [],
                errors: ["Cache.Error"],
                license: "Apache License 2.0"
            )
            let text = Draft.Render()(draft)
            let headings = text.split(separator: "\n").filter { $0.hasPrefix("#") }
            #expect(
                headings == [
                    "# swift-cache", "## Products", "## Traits", "## Installation", "## Error Handling", "## License",
                ]
            )
            #expect(text.contains("layer 2 (what is built from atoms alone)"))
            #expect(text.contains("| `Cache` | `Cache`, `Cache Core` |"))
            #expect(text.contains("`Effect`. None is enabled by default."))
            #expect(text.contains(#".package(url: "https://github.com/swift-molecules/swift-cache.git", branch: "main")"#))
            #expect(text.contains(#".product(name: "Cache", package: "swift-cache")"#))
            #expect(text.contains("`Cache.Error`"))
        }

        @Test
        func `a package outside the layers names no layer, and one without errors or traits has neither section`() {
            let draft = Draft(
                repository: "coenttb/swift-example",
                description: "An example.",
                products: [],
                traits: [],
                defaultTraits: [],
                errors: [],
                license: "MIT License"
            )
            let text = Draft.Render()(draft)
            #expect(!text.contains("Swift Institute"))
            #expect(!text.contains("## Traits"))
            #expect(!text.contains("## Error Handling"))
            #expect(text.hasSuffix("## License\n\nMIT License. See [LICENSE.md](LICENSE.md).\n"))
        }

        @Test
        func `the license line names Apache 2.0 from its header and takes any other license's title`() {
            #expect(Draft.license(from: "   Apache License\n   Version 2.0, January 2004\n") == "Apache License 2.0")
            #expect(Draft.license(from: "MIT License\n\nCopyright") == "MIT License")
            #expect(Draft.license(from: "# GNU Affero General Public License\n") == "GNU Affero General Public License")
        }
    }
}
