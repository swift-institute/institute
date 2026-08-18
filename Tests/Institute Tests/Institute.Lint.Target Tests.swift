import File_System
import SPM_Standard
import Testing

@testable import Institute_Conversion
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Doctor
@testable import Institute_Instruments
@testable import Institute_Inventory
@testable import Institute_Lint
@testable import Institute_Model
@testable import Institute_Pages

extension Institute.Lint.Target {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Institute.Lint.Target.Test.Unit {
    @Test
    func `declared target kinds resolve to their SwiftPM roots`() throws {
        let package = File.Directory("/fixture/package")
        let roots = try Institute.Lint.Target.roots(
            [
                .init(name: .init(_unchecked: "Library"), kind: .regular),
                .init(name: .init(_unchecked: "Tool"), kind: .executable),
                .init(name: .init(_unchecked: "Library Tests"), kind: .test),
                .init(name: .init(_unchecked: "Generator"), kind: .plugin),
                .init(name: .init(_unchecked: "Macros"), kind: .macro),
                .init(name: .init(_unchecked: "CLibrary"), kind: .system),
                .init(name: .init(_unchecked: "Artifact"), kind: .binary, path: "Artifact.zip"),
            ],
            at: package
        )

        #expect(
            roots.map(\.description) == [
                package[directory: "Sources"][directory: "Library"].description,
                package[directory: "Sources"][directory: "Tool"].description,
                package[directory: "Tests"][directory: "Library Tests"].description,
                package[directory: "Plugins"][directory: "Generator"].description,
                package[directory: "Sources"][directory: "Macros"].description,
                package[directory: "Sources"][directory: "CLibrary"].description,
            ]
        )
    }

    @Test
    func `explicit target paths win without admitting neighboring trees`() throws {
        let package = File.Directory("/fixture/package")
        let roots = try Institute.Lint.Target.roots(
            [
                .init(
                    name: .init(_unchecked: "Library"),
                    kind: .regular,
                    path: "Code/Library"
                ),
                .init(
                    name: .init(_unchecked: "Declared Tests"),
                    kind: .test,
                    path: "Tests/Declared"
                ),
            ],
            at: package
        )
        let paths = roots.map(\.description)

        #expect(
            paths == [
                package[directory: "Code"][directory: "Library"].description,
                package[directory: "Tests"][directory: "Declared"].description,
            ]
        )
        #expect(!paths.contains("/fixture/package/Scripts"))
        #expect(!paths.contains("/fixture/package/Experiments"))
        #expect(!paths.contains("/fixture/package/Research"))
        #expect(!paths.contains("/fixture/package/Tests/Undeclared"))
    }
}

extension Institute.Lint.Target.Test.`Edge Case` {
    /// A platform-native absolute path outside the package, so the
    /// refusal fires on every platform (a bare `/outside` is not an
    /// absolute path on Windows).
    static var absoluteOutside: Swift.String {
        #if os(Windows)
            "C:\\outside"
        #else
            "/outside"
        #endif
    }

    @Test
    func `a package-root target makes the whole package declared scope`() throws {
        let package = File.Directory("/fixture/package")
        let roots = try Institute.Lint.Target.roots(
            [
                .init(name: .init(_unchecked: "Package"), kind: .regular, path: ".")
            ],
            at: package
        )

        #expect(roots.map(\.description) == ["/fixture/package"])
    }

    @Test
    func `duplicate declared roots are scanned once`() throws {
        let package = File.Directory("/fixture/package")
        let roots = try Institute.Lint.Target.roots(
            [
                .init(name: .init(_unchecked: "One"), kind: .regular, path: "Sources/Shared"),
                .init(name: .init(_unchecked: "Two"), kind: .regular, path: "Sources/Shared"),
            ],
            at: package
        )

        #expect(
            roots.map(\.description)
                == [package[directory: "Sources"][directory: "Shared"].description]
        )
    }

    @Test
    func `absolute and escaping target paths are refused`() throws {
        let package = File.Directory("/fixture/package")

        #expect(throws: Institute.Error.self) {
            try Institute.Lint.Target.roots(
                [
                    .init(
                        name: .init(_unchecked: "Absolute"),
                        kind: .regular,
                        path: Self.absoluteOutside
                    )
                ],
                at: package
            )
        }
        #expect(throws: Institute.Error.self) {
            try Institute.Lint.Target.roots(
                [.init(name: .init(_unchecked: "Escape"), kind: .regular, path: "../outside")],
                at: package
            )
        }
    }
}
