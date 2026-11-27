import Institute_Model
import Testing

@testable import Institute_Inventory

@Suite
struct `Institute.Inventory.Walker Tests` {
    func paths(_ source: Swift.String) -> [Swift.String] {
        Institute.Inventory.Walker.facts(source: source).types.map { $0.path.joined(separator: ".") }
    }

    func references(_ source: Swift.String) -> [Swift.String] {
        Institute.Inventory.Walker.facts(source: source).references.map {
            "\($0.from.joined(separator: ".")) \($0.written) \($0.position.rawValue)\($0.generic ? " generic" : "")"
        }
    }

    @Test
    func `nested types and types in extensions get their dotted path`() {
        let source = """
            enum Picture {
                struct Encoded {
                    struct Pixel {}
                }
            }
            extension Swift.String {
                struct Counted {}
            }
            extension Picture.Encoded {
                enum Channel { case red, green }
            }
            func make() {
                struct Local {}
            }
            """
        #expect(
            paths(source) == [
                "Picture", "Picture.Encoded", "Picture.Encoded.Pixel", "Swift.String.Counted",
                "Picture.Encoded.Channel",
            ]
        )
        let facts = Institute.Inventory.Walker.facts(source: source)
        #expect(facts.types.map(\.isInExtension) == [false, false, false, true, true])
        #expect(facts.types.last?.cases == 2)
        #expect(facts.extensions.map { $0.extended.joined(separator: ".") } == ["Swift.String", "Picture.Encoded"])
    }

    @Test
    func `a module selector keeps the type part and records the module`() {
        let source = """
            #if Byte
            extension Swift::String {
                public struct Coder: Byte.Coding<Swift::String> {}
            }
            #endif
            """
        let facts = Institute.Inventory.Walker.facts(source: source)
        #expect(facts.types.count == 1)
        #expect(facts.types.first?.path == ["String", "Coder"])
        #expect(facts.types.first?.module == "Swift")
        #expect(facts.types.first?.condition == "Byte")
        #expect(facts.extensions.first?.module == "Swift")
        #expect(references(source).contains("String.Coder Swift::String generic_argument"))
    }

    @Test
    func `access, generic parameters, stored properties and inheritance`() {
        let source = """
            public extension Buffer {
                struct Linear<Element: ~Copyable, Storage>: Sendable, Equatable {
                    var count: Int
                    let a, b: Element
                    var computed: Int { count }
                    var observed: Int = 0 { didSet {} }
                    static var shared: Int = 0
                }
                private struct Hidden {}
            }
            typealias Bytes = [UInt8]
            """
        let types = Institute.Inventory.Walker.facts(source: source).types
        #expect(types.map(\.access) == ["public", "private", "internal"])
        #expect(types[0].generics == ["Element", "Storage"])
        #expect(types[0].stored == 4)
        #expect(types[0].inherits == ["Sendable", "Equatable"])
        #expect(types[0].cases == -1)
        #expect(types[2].kind == "typealias")
        #expect(types[2].aliased == "[UInt8]")
    }

    @Test
    func `reference positions`() {
        let source = """
            struct Holder<T>: Codable where T: Hashable {
                var stored: Picture.Encoded.Pixel
                var computed: Size { Size() }
                func f(_ x: Point) -> Array<Pixel> {
                    let y = Picture.Color.red
                    return []
                }
                enum Shape { case circle(Radius) }
                typealias Alias = Target.Kind
                var generic: T
            }
            extension Picture.Encoded: Sendable {}
            """
        let found = references(source)
        #expect(found.contains("Holder Codable inheritance"))
        #expect(found.contains("Holder Hashable constraint"))
        #expect(found.contains("Holder T constraint generic"))
        #expect(found.contains("Holder Picture.Encoded.Pixel stored"))
        #expect(found.contains("Holder Size return"))
        #expect(found.contains("Holder Size body"))
        #expect(found.contains("Holder Point parameter"))
        #expect(found.contains("Holder Array return"))
        #expect(found.contains("Holder Pixel generic_argument"))
        #expect(found.contains("Holder Picture.Color body"))
        #expect(found.contains("Holder.Shape Radius case"))
        #expect(found.contains("Holder Target.Kind alias"))
        #expect(found.contains("Holder T stored generic"))
        #expect(found.contains(" Picture.Encoded extension"))
        #expect(found.contains("Picture.Encoded Sendable inheritance"))
        #expect(!found.contains("Holder Picture body"))
    }

    @Test
    func `imports with access, exported and condition`() {
        let source = """
            @_exported public import Byte
            internal import struct Swift.String
            #if canImport(Darwin)
            import Darwin
            #elseif os(Linux)
            import Glibc
            #endif
            """
        let imports = Institute.Inventory.Walker.facts(source: source).imports
        #expect(imports.map(\.module) == ["Byte", "Swift", "Darwin", "Glibc"])
        #expect(imports.map(\.access) == ["public", "internal", "", ""])
        #expect(imports.map(\.exported) == [true, false, false, false])
        #expect(imports[2].condition == "canImport(Darwin)")
        #expect(imports[3].condition == "!(canImport(Darwin)) && os(Linux)")
    }

    func members(_ source: Swift.String) -> [Swift.String] {
        Institute.Inventory.Walker.facts(source: source).members.map {
            "\($0.owner.joined(separator: ".")) \($0.kind) \($0.name) \($0.access)"
        }
    }

    @Test
    func `every member kind gets its reference name and its owner`() {
        let source = """
            struct Parser {
                var count: Int
                let a, b: Element
                var computed: Swift.Int { count }
                init(_ input: Input) {}
                init?(named name: String, strict: Bool = false) {}
                deinit {}
                func parse(_ input: inout Input, from start: @escaping () -> Int, rest: Int...) -> Output? { nil }
                func `repeat`() {}
                subscript(index: Int) -> Element { a }
                subscript(checked index: Int, _ other: Int) -> Element? { nil }
                static func == (lhs: Self, rhs: Self) -> Bool { true }
                enum Mode { case fast, slow(Int, limit: Double) }
            }
            protocol Shape {
                associatedtype Unit
                var area: Unit { get }
                func scaled(by factor: Double) -> Self
            }
            func free(_ x: Int) {}
            let shared = 1
            """
        let facts = Institute.Inventory.Walker.facts(source: source)
        #expect(
            members(source) == [
                "Parser var count internal", "Parser let a internal", "Parser let b internal",
                "Parser var computed internal", "Parser init init(_:) internal",
                "Parser init init(named:strict:) internal", "Parser func parse(_:from:rest:) internal",
                "Parser func repeat() internal", "Parser subscript subscript(_:) internal",
                "Parser subscript subscript(checked:_:) internal", "Parser func ==(_:_:) internal",
                "Parser.Mode case fast internal", "Parser.Mode case slow internal",
                "Shape var area internal", "Shape func scaled(by:) internal",
                " func free(_:) internal", " let shared internal",
            ]
        )
        #expect(facts.members.map(\.stored).prefix(4) == [true, true, true, false])
        #expect(facts.members.map(\.result).prefix(4) == ["Int", "Element", "Element", "Swift.Int"])
        #expect(facts.members[5].parameters == ["String", "Bool"])
        #expect(facts.members[6].parameters == ["inout Input", "@escaping () -> Int", "Int..."])
        #expect(facts.members[6].result == "Output?")
        #expect(facts.members[9].result == "Element?")
        #expect(facts.members[10].shared)
        #expect(facts.members[12].parameters == ["Int", "Double"])
        #expect(facts.members[13].stored == false)
        #expect(facts.members.last?.stored == true)
    }

    @Test
    func `a member takes the access of its extension, protocol or enum unless it writes its own`() {
        let source = """
            public extension Buffer {
                func read() {}
                internal func hidden() {}
                struct Linear { var count: Int }
            }
            private extension Buffer {
                func secret() {}
            }
            public protocol Source {
                func next() -> Int
            }
            extension Source {
                func twice() {}
            }
            public enum Mode {
                case fast
                var slow: Bool { false }
                public private(set) static var current = 0
            }
            """
        let facts = Institute.Inventory.Walker.facts(source: source)
        #expect(
            members(source) == [
                "Buffer func read() public", "Buffer func hidden() internal", "Buffer.Linear var count internal",
                "Buffer func secret() fileprivate", "Source func next() public", "Source func twice() internal",
                "Mode case fast public", "Mode var slow internal", "Mode var current public",
            ]
        )
        #expect(facts.members.map(\.extended) == [true, true, false, true, false, true, false, false, false])
    }

    @Test
    func `static, mutating, async, throws, generics and condition`() {
        let source = """
            extension Stack {
                #if os(Linux)
                mutating func push<T, U: Sendable>(_ value: T, with other: U) async throws(Stack.Error) {}
                #else
                class func make() throws -> Self { fatalError() }
                #endif
                static var shared: Self { get async throws { fatalError() } }
                var first: Int { mutating get { 0 } }
                func each(_ body: (Int) throws -> Void) rethrows {}
                subscript<K>(key: K) -> Int { get throws(Missing) { 0 } }
                func pair() -> (
                    left: Int,
                    right: Int
                ) { (0, 0) }
            }
            """
        let found = Institute.Inventory.Walker.facts(source: source).members
        #expect(found.map(\.name) == ["push(_:with:)", "make()", "shared", "first", "each(_:)", "subscript(_:)", "pair()"])
        #expect(found.map(\.shared) == [false, true, true, false, false, false, false])
        #expect(found.map(\.mutating) == [true, false, false, true, false, false, false])
        #expect(found.map(\.async) == [true, false, true, false, false, false, false])
        #expect(found.map(\.thrown) == ["Stack.Error", "throws", "throws", "", "rethrows", "Missing", ""])
        #expect(found.map(\.generics) == [["T", "U"], [], [], [], [], ["K"], []])
        #expect(found.map(\.condition) == ["os(Linux)", "!(os(Linux))", "", "", "", "", ""])
        #expect(found[4].parameters == ["(Int) throws -> Void"])
        #expect(found[6].result == "( left: Int, right: Int )")
        #expect(found.allSatisfy { !$0.stored })
        #expect(found.map(\.line) == [3, 5, 7, 8, 9, 10, 11])
    }

    @Test
    func `members local to a body are left out`() {
        let source = """
            struct Outer {
                func run() {
                    let local = 1
                    func helper() {}
                    struct Inner { var x: Int; func f() {} }
                    _ = { let captured = 2 }
                }
                var computed: Int {
                    let inside = 1
                    return inside
                }
                var observed: Int = 0 {
                    didSet { let old = oldValue }
                }
            }
            """
        #expect(
            members(source) == ["Outer func run() internal", "Outer var computed internal", "Outer var observed internal"]
        )
        #expect(Institute.Inventory.Walker.facts(source: source).members.map(\.stored) == [false, false, true])
    }

    @Test
    func `member uses are counted by the name the use site writes`() {
        let source = """
            func run() {
                let x = buffer.count
                buffer.append(1)
                buffer.insert(2, at: 0)
                buffer.insert(3, at: 1)
                parse(input, from: start)
                let mode: Mode = .fast
                let other = Mode.slow(1, limit: 2)
                show(.named("a"))
                values.map { $0.count }
                values.reduce(0) { $0 + $1 }
                let f = buffer.remove(at:)
                Swift.print(x)
                `repeat`.`default`()
                cast<Int>(x)
                _ = Picture.Encoded.Pixel(1)
                _ = self.storage?.first!.id
            }
            """
        let uses = Institute.Inventory.Walker.facts(source: source).uses
        #expect(
            uses == [
                "count": 2, "append(_:)": 1, "insert(_:at:)": 2, "parse(_:from:)": 1, "fast": 1,
                "slow(_:limit:)": 1, "show(_:)": 1, "named(_:)": 1, "map()": 1, "reduce(_:)": 1,
                "remove(at:)": 1, "print(_:)": 1, "default()": 1, "cast(_:)": 1, "storage": 1, "first": 1, "id": 1,
            ]
        )
    }
}
