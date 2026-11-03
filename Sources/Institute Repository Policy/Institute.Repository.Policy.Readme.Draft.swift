public import Institute_Model

extension Institute.Repository.Policy.Readme {
    public struct Draft: Sendable, Equatable {
        public let repository: Swift.String
        public let description: Swift.String
        public let products: [Product]
        public let traits: [Swift.String]
        public let defaultTraits: [Swift.String]
        public let errors: [Swift.String]
        public let license: Swift.String

        public init(
            repository: Swift.String,
            description: Swift.String,
            products: [Product],
            traits: [Swift.String],
            defaultTraits: [Swift.String],
            errors: [Swift.String],
            license: Swift.String
        ) {
            self.repository = repository
            self.description = description
            self.products = products
            self.traits = traits
            self.defaultTraits = defaultTraits
            self.errors = errors
            self.license = license
        }
    }
}

extension Institute.Repository.Policy.Readme.Draft {
    public static func license(from text: Swift.String) -> Swift.String {
        let lines = text.split(separator: "\n").map { $0.trimmingPrefix(while: \.isWhitespace) }.filter { !$0.isEmpty }
        guard let first = lines.first else { return "See LICENSE.md" }
        let title = Swift.String(first).trimmingSuffixWhitespace
        if title == "Apache License", lines.count > 1, lines[1].hasPrefix("Version 2.0") {
            return "Apache License 2.0"
        }
        return title.hasPrefix("#") ? Swift.String(title.drop { $0 == "#" || $0 == " " }) : title
    }
}

extension Swift.String {
    fileprivate var trimmingSuffixWhitespace: Swift.String {
        var text = self
        while text.last?.isWhitespace == true { text.removeLast() }
        return text
    }
}
