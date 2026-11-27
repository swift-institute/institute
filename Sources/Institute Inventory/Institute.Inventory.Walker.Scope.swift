internal import Institute_Model

extension Institute.Inventory.Walker {
    /// One enclosing scope: a type body, an extension body, or a
    /// declaration that only brings generic parameters into scope.
    struct Scope {
        var kind: Kind
        var path: [Swift.String]
        var generics: [Swift.String]
        var moduleSelector: Swift.String
        var access: Swift.String
    }
}
