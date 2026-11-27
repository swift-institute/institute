internal import Institute_Model
internal import SwiftSyntax

extension Institute.Inventory.Walker {
    /// What the head of one member declaration says, as written.
    struct Signature {
        var kind: Swift.String
        var name: Swift.String
        var generics: [Swift.String] = []
        var parameters: [Swift.String] = []
        var async = false
        var thrown = ""
        var result = ""
        var stored = false
        var mutating = false
    }
}

extension Institute.Inventory.Walker.Signature {
    /// An operator's parameters carry no labels: `==(_:_:)`.
    init(_ node: FunctionDeclSyntax) {
        let list = node.signature.parameterClause.parameters
        let labels =
            if case .identifier = node.name.tokenKind {
                list.map(\.firstName.text)
            } else {
                list.map { _ in "_" }
            }
        self.init(kind: "func", name: Self.strip(node.name.text) + Self.labels(labels))
        generics = Institute.Inventory.Walker.Visitor.names(node.genericParameterClause)
        parameters = Self.types(list)
        effects(node.signature.effectSpecifiers)
        result = node.signature.returnClause.map { Self.written($0.type) } ?? ""
    }

    init(_ node: InitializerDeclSyntax) {
        let list = node.signature.parameterClause.parameters
        self.init(kind: "init", name: "init" + Self.labels(list.map(\.firstName.text)))
        generics = Institute.Inventory.Walker.Visitor.names(node.genericParameterClause)
        parameters = Self.types(list)
        effects(node.signature.effectSpecifiers)
    }

    /// A subscript parameter has a label only when it writes two names.
    init(_ node: SubscriptDeclSyntax) {
        let list = node.parameterClause.parameters
        let labels = list.map { $0.secondName == nil ? "_" : $0.firstName.text }
        self.init(kind: "subscript", name: "subscript" + Self.labels(labels))
        generics = Institute.Inventory.Walker.Visitor.names(node.genericParameterClause)
        parameters = Self.types(list)
        result = Self.written(node.returnClause.type)
        accessors(node.accessorBlock)
        stored = false
    }

    /// One binding of a `var` or `let`. A binding without a type takes the
    /// one written on a later binding, as in `let a, b: Int`.
    init(_ binding: PatternBindingSyntax, in node: VariableDeclSyntax) {
        let name =
            binding.pattern.as(IdentifierPatternSyntax.self).map { Self.strip($0.identifier.text) }
            ?? binding.pattern.trimmedDescription
        self.init(kind: node.bindingSpecifier.text, name: name)
        accessors(binding.accessorBlock)
        if let written = binding.typeAnnotation {
            result = Self.written(written.type)
        } else if binding.initializer == nil {
            var passed = false
            for other in node.bindings {
                if other.id == binding.id {
                    passed = true
                } else if passed, let written = other.typeAnnotation {
                    result = Self.written(written.type)
                    break
                } else if passed, other.initializer != nil {
                    break
                }
            }
        }
    }

    init(_ element: EnumCaseElementSyntax) {
        self.init(kind: "case", name: Self.strip(element.name.text))
        parameters = element.parameterClause?.parameters.map { Self.written($0.type) } ?? []
    }
}

extension Institute.Inventory.Walker.Signature {
    static func strip(_ text: Swift.String) -> Swift.String {
        Institute.Inventory.Walker.Visitor.strip(text)
    }

    /// `(a:_:)` for the labels `a` and `_`.
    static func labels(_ labels: [Swift.String]) -> Swift.String {
        "(" + labels.map { strip($0) + ":" }.joined() + ")"
    }

    /// A type as written, each run of whitespace as one space.
    static func written(_ type: TypeSyntax) -> Swift.String {
        type.trimmedDescription.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func types(_ list: FunctionParameterListSyntax) -> [Swift.String] {
        list.map { written($0.type) + ($0.ellipsis == nil ? "" : "...") }
    }

    mutating func effects(_ specifiers: (some EffectSpecifiersSyntax)?) {
        guard let specifiers else { return }
        self.async = specifiers.asyncSpecifier != nil
        if let clause = specifiers.throwsClause {
            self.thrown = clause.type.map(Self.written) ?? clause.throwsSpecifier.text
        }
    }

    /// A binding without accessors, or with observers only, is stored; a
    /// getter carries the effects and may be `mutating`.
    mutating func accessors(_ block: AccessorBlockSyntax?) {
        guard let block else {
            self.stored = true
            return
        }
        guard case .accessors(let list) = block.accessors else { return }
        self.stored = list.allSatisfy { ["willSet", "didSet"].contains($0.accessorSpecifier.text) }
        for accessor in list where accessor.accessorSpecifier.text == "get" {
            effects(accessor.effectSpecifiers)
            if accessor.modifiers.contains(where: { $0.name.text == "mutating" }) { self.mutating = true }
        }
    }
}
