import File_System
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

/// The default-bundle classification: layer roots take their layer's
/// bundle, the control-plane checkouts are institute-class by identity,
/// and everything else is refused rather than guessed.
@Suite
struct `Institute Lint Bundle Tests` {
    static let hierarchy = File.Directory("/checkout/swift-institute")

    @Test
    func `a package under a layer root takes that layer's bundle`() {
        #expect(
            Institute.Lint.Bundle.resolve(
                File.Directory("/checkout/swift-institute/swift-primitives/swift-byte"),
                under: Self.hierarchy
            ) == .primitives
        )
        #expect(
            Institute.Lint.Bundle.resolve(
                File.Directory("/checkout/swift-institute/swift-standards/swift-iso"),
                under: Self.hierarchy
            ) == .standards
        )
        #expect(
            Institute.Lint.Bundle.resolve(
                File.Directory("/checkout/swift-institute/swift-foundations/swift-json"),
                under: Self.hierarchy
            ) == .institute
        )
    }

    @Test
    func `the control-plane checkouts are institute-class by identity`() {
        #expect(
            Institute.Lint.Bundle.resolve(
                File.Directory("/checkout/swift-institute/institute"),
                under: Self.hierarchy
            ) == .institute
        )
        #expect(
            Institute.Lint.Bundle.resolve(
                File.Directory("/checkout/swift-institute/institute-application"),
                under: Self.hierarchy
            ) == .institute
        )
    }

    /// The identity match is against the checkout at the hierarchy root,
    /// never against a deeper directory that shares the name — that
    /// would be the path guess the refusal exists to prevent.
    @Test
    func `a nested directory sharing a control-plane name is still refused`() {
        #expect(
            Institute.Lint.Bundle.resolve(
                File.Directory("/checkout/swift-institute/vendor/institute"),
                under: Self.hierarchy
            ) == nil
        )
        #expect(
            Institute.Lint.Bundle.resolve(
                File.Directory("/checkout/swift-institute/institute/Fixtures/institute"),
                under: Self.hierarchy
            ) == nil
        )
    }

    @Test
    func `an unknown root and a package outside the hierarchy are refused`() {
        #expect(
            Institute.Lint.Bundle.resolve(
                File.Directory("/checkout/swift-institute/unrelated/package"),
                under: Self.hierarchy
            ) == nil
        )
        #expect(
            Institute.Lint.Bundle.resolve(
                File.Directory("/elsewhere/swift-primitives/swift-byte"),
                under: Self.hierarchy
            ) == nil
        )
        #expect(
            Institute.Lint.Bundle.resolve(
                Self.hierarchy,
                under: Self.hierarchy
            ) == nil
        )
    }
}
