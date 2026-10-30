public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `compound identifier` = Lint.Rule(
        id: "compound identifier",
        default: .warning,
        controls: [
            .init(
                id: "compound identifier public compound",
                source: "public func openWrite() {}",
                path: "Sources/Naming Core/Compound.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "compound identifier single token",
                source: "public func open() {}",
                path: "Sources/Naming Core/SingleToken.swift",
                expectation: .clean
            ),
            .init(
                id: "compound identifier dependency key witness",
                source: "extension Balance: @retroactive Dependency.Key { public static var liveValue: Client { .live }; public static let testValue: Client = liveValue }",
                path: "Sources/Naming Core/Balance.swift",
                expectation: .clean
            ),
            .init(
                id: "compound identifier dependency key name without conformance",
                source: "extension Balance { public static var liveValue: Client { .live } }",
                path: "Sources/Naming Core/Balance.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "compound identifier boolean prefix",
                source: "public var isEmpty: Bool { false }",
                path: "Sources/Naming Core/BooleanPrefix.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            guard !namingIsPackageManifest(source.file.filePath) else { return [] }
            let visitor = NamingCompoundVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let namingCompoundMessage: Swift::String =
    "[compound identifier] [API-NAME-002]: method or property has a compound "
    + "camelCase name (e.g., `walkFiles` instead of `walk.files()`). "
    + "**Default disposition**: refactor to nested accessors — "
    + "`instance.open.write { }` not `instance.openWrite { }`; "
    + "`dir.walk.files()` not `dir.walkFiles()`. "
    + "**Already exempt** (rule does not fire): boolean prefixes "
    + "(`is`/`has`/`should`/`will`/`did`/`can`/`must`); declarations below "
    + "`package` visibility, because they are not consumer-observable API; swift-testing "
    + "scaffolding — declarations carrying `@Test`/`@Suite` and members of a "
    + "`@Suite` type, per #53 (a compound `@Test` name is still reported, by "
    + "`test function naming`, whose fix is the backticked descriptive form); "
    + "terminology in targets declared by the source profile as preserving vocabulary "
    + "imposed by an external specification authority; "
    + "documented "
    + "stdlib-vocabulary names (`rawValue`, `flatMap`, `swapAt`, `storeBytes`, "
    + "`withUnsafeBufferPointer`, etc. — see "
    + "`namingCompoundSwiftNativeIdiomCitations` in this rule's source for "
    + "the full citation set); the 8 `@resultBuilder` method names per "
    + "SE-0289/SE-0348. "
    + "**A finding does not by itself mean the name must change.** This rule "
    + "checks the SHAPE of the name; it cannot see whether a namespace to "
    + "group into exists, nor why the name was chosen. Measured over the #53 "
    + "pilot, most surviving findings correctly resolve to leaving the code "
    + "alone. Two shapes are known-legitimate and are NOT recognizable from "
    + "syntax, so the rule still fires on them by design: (a) a two-word "
    + "property with no sibling in its type sharing a leading word — there is "
    + "nothing to group, and the single-member decision tree says not to "
    + "manufacture a namespace (the rule cannot check this: the "
    + "one-extension-per-member file convention scatters a type's members "
    + "across files, and a same-file sibling test would exempt nearly "
    + "everything); (b) vocabulary held deliberately in lockstep with a cited "
    + "external reference implementation outside a profile-declared externally standardized "
    + "target, where renaming breaks traceability to the source. For either, leave "
    + "the code and — where the site warrants "
    + "a durable record — suppress that one site with "
    + "`// swift-linter:disable:next compound identifier` plus a `// REASON:` "
    + "naming the shape or citing the reference. "
    + "**Accept-as-warning** disposition (rule fires legitimately, leave the "
    + "warning): when the name mirrors a stdlib type's API at a consumer-"
    + "facing typed-input bridge (e.g., a typed-Cardinal-input overload of "
    + "`OutputSpan.removeLast` mirrors `Array.removeLast(_:Int)`), OR a "
    + "protocol this extension conforms to requires this exact name but "
    + "isn't yet in the witness allowlist "
    + "(`namingCompoundProtocolWitnessMethodCitations` in this rule's "
    + "source — entries are proposed in lint drains with a "
    + "`Protocol.requirement` citation and ratified per #16 Option C "
    + "Entry III.d). The warning IS the intended "
    + "signal — review each canary, confirm the justification still holds, "
    + "leave the warning. Don't silently disable; don't fix-source against "
    + "the rule's intent. If you've confirmed a name is broadly applicable "
    + "stdlib-mirror vocabulary, propose adding it to "
    + "`namingCompoundSwiftNativeIdiomCitations` with its Swift citation."

private let namingCompoundBooleanPrefixes: [Swift::String] = [
    "is", "has", "should", "will", "did", "can", "must",
]

private let namingCompoundSwiftNativeIdiomCitations: [Swift::String: Swift::String] = [
    "rawValue": "Swift.RawRepresentable.rawValue",
    "customMirror": "Swift.CustomReflectable.customMirror",
    "description": "Swift.CustomStringConvertible.description",
    "debugDescription": "Swift.CustomDebugStringConvertible.debugDescription",
    "hashValue": "Swift.Hashable.hashValue (deprecated but still applies)",
    "bitPattern": "Swift.UInt32.bitPattern / Swift.UInt64.bitPattern",
    "startIndex": "Swift.Collection.startIndex",
    "endIndex": "Swift.Collection.endIndex",
    "flatMap": "Swift.Optional.flatMap — canonical monadic-bind name",
    "compactMap": "Swift.Sequence.compactMap(_:) / Swift.Optional.compactMap(_:)",
    "forEach": "Swift.Sequence.forEach(_:)",
    "allSatisfy": "Swift.Sequence.allSatisfy(_:)",
    "withUnsafeBufferPointer":
        "Swift.Array.withUnsafeBufferPointer / Swift.Span.withUnsafeBufferPointer",
    "withUnsafeMutableBufferPointer":
        "Swift.Array.withUnsafeMutableBufferPointer / Swift.MutableSpan.withUnsafeMutableBufferPointer",
    "withContiguousStorageIfAvailable": "Swift.Sequence.withContiguousStorageIfAvailable",
    "withUnsafeMutablePointerToElements": "Swift.ManagedBuffer.withUnsafeMutablePointerToElements",
    "withUnsafeMutablePointerToHeader": "Swift.ManagedBuffer.withUnsafeMutablePointerToHeader",
    "withUnsafeMutablePointers": "Swift.ManagedBuffer.withUnsafeMutablePointers",
    "withCheckedContinuation": "Swift._Concurrency.withCheckedContinuation",
    "withTaskCancellationHandler": "Swift._Concurrency.withTaskCancellationHandler",
    "withUnsafeContinuation": "Swift._Concurrency.withUnsafeContinuation",
    "withUnsafePointer": "Swift.withUnsafePointer(to:_:)",
    "withUnsafeMutablePointer": "Swift.withUnsafeMutablePointer(to:_:)",
    "withUnsafeBytes": "Swift.withUnsafeBytes(of:_:)",
    "withUnsafeMutableBytes": "Swift.withUnsafeMutableBytes(of:_:)",
    "withUnsafeTemporaryAllocation": "Swift.withUnsafeTemporaryAllocation(byteCount:alignment:_:)",
    "mapError": "Swift.Result.mapError(_:)",
    "flatMapError": "Swift.Result.flatMapError(_:)",
    "mapKeys": "Swift.Dictionary.mapValues(_:) precedent (institute counterpart)",
    "compactMapKeys": "Swift.Dictionary.compactMapValues(_:) precedent (institute counterpart)",
    "uniqued": "swift-algorithms.uniqued() — Sequence/Collection deduplication",
    "span": "SE-0517 Span / MutableSpan — Swift.Array.span (canonical span getter)",
    "mutableSpan":
        "SE-0517 Span / MutableSpan — Swift.Array.mutableSpan (canonical mutable-span getter)",
    "withSpan": "SE-0517 Span scoped-access counterpart to the allowlisted `span` getter",
    "withMutableSpan":
        "SE-0517 MutableSpan scoped-access counterpart to the allowlisted `mutableSpan` getter",
    "removeAll": "Swift.Array.removeAll(keepingCapacity:)",
    "reserveCapacity": "Swift.Array.reserveCapacity(_:)",
    "withElement":
        "stdlib withX scoped-borrow family — 8 declaring packages across swift-molecules",
    "freeCapacity": "L1 container-family vocabulary — 4 declaring packages across swift-molecules",
    "callAsFunction": "SE-0253 — compiler-recognised callable-as-function informal protocol",
    "swapAt": "Swift.MutableCollection.swapAt(_:_:)",
    "storeBytes": "Swift.UnsafeMutableRawPointer.storeBytes(of:toByteOffset:as:)",
    "moveInitialize": "Swift.UnsafeMutablePointer.moveInitialize(from:count:)",
    "quotientAndRemainder": "Swift.BinaryInteger.quotientAndRemainder(dividingBy:)",
    "underestimatedCount": "Swift.Sequence.underestimatedCount",
]

private let namingCompoundProtocolWitnessMethodCitations: [Swift::String: (citation: Swift::String, conformanceGated: Swift::Bool)] = [
    "encodeAtomicRepresentation": (
        "Swift.AtomicRepresentable.encodeAtomicRepresentation(_:)", true
    ),
    "decodeAtomicRepresentation": (
        "Swift.AtomicRepresentable.decodeAtomicRepresentation(_:)", true
    ),
    "makeIterator": ("Swift.Sequence.makeIterator()", true),
    "liveValue": ("Dependency.Key.liveValue (swift-dependency)", true),
    "testValue": ("Dependency.Key.testValue (swift-dependency)", true),
    "previewValue": ("Dependency.Key.previewValue (swift-dependency)", true),
    "displayName": ("Identity.OAuth.Provider.displayName", true),
    "requiresTokenStorage": ("Identity.OAuth.Provider.requiresTokenStorage", true),
    "supportsRefresh": ("Identity.OAuth.Provider.supportsRefresh", true),
    "authorizationURL": ("Identity.OAuth.Provider.authorizationURL(state:redirectURI:)", false),
    "exchangeCode": ("Identity.OAuth.Provider.exchangeCode(_:redirectURI:)", false),
    "getUserInfo": ("Identity.OAuth.Provider.getUserInfo(accessToken:)", false),
    "refreshToken": ("Identity.OAuth.Provider.refreshToken(_:)", false),
    "nextSpan":
        (
            "Sequence.Iterator.`Protocol`.nextSpan(maximumCount:) — institute span-based iterator primitive aligned with Swift.IteratorProtocol vocabulary",
            true
        ),
    "removeAll":
        (
            "Swift.RangeReplaceableCollection.removeAll() / Swift.Sequence.removeAll(where:) / Sequence.`Clearable`.removeAll()",
            true
        ),
    "removeLast":
        (
            "Swift.RangeReplaceableCollection.removeLast() / Swift.Array.removeLast() / Collection.Remove.Last.removeLast(_:) — drop-in stdlib replacement vocabulary",
            true
        ),
]

internal final class NamingCompoundVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let visibility = Lint.Visibility.effective(of: Syntax(node))
        guard visibility == .public || visibility == .package else {
            return .visitChildren
        }
        if isInsideFunctionLikeContext(Syntax(node)) {
            return .visitChildren
        }
        if Naming.isBackticked(node.name) {
            return .visitChildren
        }
        if Naming.isTestScaffolding(Syntax(node), attributes: node.attributes) {
            return .visitChildren
        }
        let name = node.name.text
        if name == "visitPost",
            node.modifiers.contains(where: { $0.name.tokenKind == .keyword(.override) })
        {
            return .visitChildren
        }
        guard isCompoundIdentifier(name) else {
            return .visitChildren
        }
        if Naming.Build.methods.contains(name) {
            return .visitChildren
        }
        if let entry = namingCompoundProtocolWitnessMethodCitations[name] {
            if !entry.conformanceGated {
                return .visitChildren
            }
            let conformances = Naming.conformances(Syntax(node))
            if !conformances.isEmpty {
                return .visitChildren
            }
        }
        emit(at: node.name.positionAfterSkippingLeadingTrivia)
        return .visitChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        let visibility = Lint.Visibility.effective(of: Syntax(node))
        guard visibility == .public || visibility == .package else {
            return .visitChildren
        }
        if isInsideFunctionLikeContext(Syntax(node)) {
            return .visitChildren
        }
        if Naming.isTestScaffolding(Syntax(node), attributes: node.attributes) {
            return .visitChildren
        }
        for binding in node.bindings {
            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }
            if Naming.isBackticked(pattern.identifier) {
                continue
            }
            let name = pattern.identifier.text
            guard isCompoundIdentifier(name) else {
                continue
            }
            if let entry = namingCompoundProtocolWitnessMethodCitations[name] {
                if !entry.conformanceGated {
                    continue
                }
                if !Naming.conformances(Syntax(node)).isEmpty {
                    continue
                }
            }
            emit(at: pattern.identifier.positionAfterSkippingLeadingTrivia)
        }
        return .visitChildren
    }

    private func isInsideFunctionLikeContext(_ node: Syntax) -> Bool {
        var current: Syntax? = node.parent
        while let candidate = current {
            if candidate.is(FunctionDeclSyntax.self)
                || candidate.is(InitializerDeclSyntax.self)
                || candidate.is(AccessorDeclSyntax.self)
                || namingIsShorthandGetterAccessorBlock(candidate)
                || candidate.is(ClosureExprSyntax.self)
                || candidate.is(DeinitializerDeclSyntax.self)
                || candidate.is(SubscriptDeclSyntax.self)
            {
                return true
            }
            if candidate.is(ExtensionDeclSyntax.self)
                || candidate.is(StructDeclSyntax.self)
                || candidate.is(ClassDeclSyntax.self)
                || candidate.is(EnumDeclSyntax.self)
                || candidate.is(ActorDeclSyntax.self)
                || candidate.is(ProtocolDeclSyntax.self)
            {
                return false
            }
            current = candidate.parent
        }
        return false
    }

    private func isCompoundIdentifier(_ name: Swift::String) -> Bool {
        guard namingCompoundSwiftNativeIdiomCitations[name] == nil else {
            return false
        }
        for prefix in namingCompoundBooleanPrefixes {
            if name.hasPrefix(prefix), name.count > prefix.count {
                let nextIndex = name.index(name.startIndex, offsetBy: prefix.count)
                if name[nextIndex].isUppercase {
                    return false
                }
            }
        }
        var sawLowercase = false
        var sawUppercaseAfterLowercase = false
        for (offset, character) in name.enumerated() {
            if offset == 0 {
                guard character.isLowercase else {
                    return false
                }
                sawLowercase = true
                continue
            }
            if character.isUppercase, sawLowercase {
                sawUppercaseAfterLowercase = true
                break
            }
            if character.isLowercase || character.isNumber || character == "_" {
                continue
            }
            return false
        }
        return sawUppercaseAfterLowercase
    }

    private func emit(at position: AbsolutePosition) {
        let location = converter.location(for: position)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "compound identifier",
                message: namingCompoundMessage
            )
        )
    }
}
