public import Institute_Model

extension Institute.Repository.Policy {
    public struct Deviation: Swift.Sendable, Swift.Equatable {
        public let platforms: Swift.String
        public let embeddedTarget: Swift.String

        public init(platforms: Swift.String = "", embeddedTarget: Swift.String = "") {
            self.platforms = platforms
            self.embeddedTarget = embeddedTarget
        }
    }
}

extension Institute.Repository.Policy.Deviation {
    public static let path = ".github/metadata.yaml"

    public init(metadata text: Swift.String) {
        var values: [Swift.String: Swift.String] = [:]
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let first = line.first, first != " ", first != "#",
                let colon = line.firstIndex(of: ":")
            else { continue }
            let key = Swift.String(line[..<colon])
            var value = line[line.index(after: colon)...].trimmingPrefix(" ")
            if let hash = value.indices.first(where: { value[$0] == "#" && $0 > value.startIndex && value[value.index(before: $0)] == " " }) {
                value = value[..<hash]
            }
            while value.last == " " { value = value.dropLast() }
            if value.count >= 2, let quote = value.first, quote == "\"" || quote == "'", value.last == quote {
                value = value.dropFirst().dropLast()
            }
            values[key] = Swift.String(value)
        }
        self.init(platforms: values["platforms"] ?? "", embeddedTarget: values["embedded-target"] ?? "")
    }
}
