internal import Institute_Development
internal import Institute_Inventory
internal import Institute_Lint
public import Institute_Model
internal import Institute_Pages

extension Institute.Doctor.Uniqueness {
    /// The composed-graph namespace a name lives in.
    ///
    /// Library products and targets collide independently: SwiftPM
    /// resolves product dependencies and module names as separate
    /// namespaces, so a product sharing a name with a target is lawful
    /// while two repositories sharing either is not.
    public enum Namespace: Equatable, Sendable {
        /// A library product name — the addressable dependency surface
        /// of the composed graph.
        case product
        /// A buildable (regular or executable) target name — a module
        /// name in every composed slice that compiles it.
        case target
    }
}

extension Institute.Doctor.Uniqueness.Namespace: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .product: "product"
        case .target: "target"
        }
    }
}
