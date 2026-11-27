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
}
