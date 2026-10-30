public import Command
public import Command_Schema
public import Institute_Model

extension Institute.Application {
    /// `institute organizations` — `Institute.Organization`, the one roster
    /// of the Institute's GitHub organizations, as one JSON array of names
    /// in declaration order, optionally narrowed to one layer. Workflows
    /// that fan out over the organizations read their matrix from here
    /// instead of keeping a list of their own.
    public struct Organizations: Sendable, Command_Schema.Command.`Protocol` {
        public var layer: Swift.String

        public init(layer: Swift.String = "") {
            self.layer = layer
        }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(
                name: "organizations",
                abstract: "Print the Institute's organizations as one JSON array."
            )
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Option(
                    \.layer,
                    name: .long(.literal("layer")),
                    placeholder: "layer",
                    help: .init(
                        abstract: "Only this layer: "
                            + Institute.Organization.Layer.allCases.map(Self.name).joined(separator: ", ") + "."
                    )
                )
            }
        }

        public mutating func validate() throws(Command_Schema.Command.Error) {
            guard layer.isEmpty || Self.layer(named: layer) != nil else {
                throw .validationFailed(reason: "--layer \(layer) is not a layer")
            }
        }

        public mutating func run() async throws(Institute.Error) {
            print(Self.matrix(layer: Self.layer(named: layer)))
        }

        /// `["swift-institute","swift-atoms",…]`. Organization names are
        /// lowercase letters and hyphens, so no character needs escaping.
        static func matrix(layer: Institute.Organization.Layer?) -> Swift.String {
            let selected = Institute.Organization.allCases.filter { layer == nil || $0.layer == layer }
            return "[" + selected.map { "\"\($0.rawValue)\"" }.joined(separator: ",") + "]"
        }

        static func name(_ layer: Institute.Organization.Layer) -> Swift.String {
            switch layer {
            case .atoms: "atoms"
            case .molecules: "molecules"
            case .standards: "standards"
            case .compositions: "compositions"
            case .control: "control"
            }
        }

        static func layer(named name: Swift.String) -> Institute.Organization.Layer? {
            Institute.Organization.Layer.allCases.first { Self.name($0) == name }
        }
    }
}
