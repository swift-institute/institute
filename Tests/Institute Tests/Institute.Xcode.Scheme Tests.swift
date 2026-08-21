import Foundation
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

extension Institute.Xcode.Scheme {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Institute.Xcode.Scheme.Test.Unit {
    private static let plan = Institute.Xcode.Scheme.Plan(buildables: [
        Institute.Xcode.Scheme.Buildable(
            reference: "../swift-primitives/swift-dimension-primitives",
            target: "Dimension Primitives"
        ),
        Institute.Xcode.Scheme.Buildable(
            reference: "../swift-standards/swift-color-standard",
            target: "Color Standard"
        ),
        Institute.Xcode.Scheme.Buildable(
            reference: "../swift-standards/swift-color-standard",
            target: "Theme"
        ),
    ], testables: [
        .init(
            reference: "../swift-standards/swift-color-standard",
            target: "Color Standard Tests"
        )
    ])

    @Test
    func `one scheme names buildables in more than one container`() {
        // This is the entire mechanism. Xcode autogenerates a scheme per
        // product and `xcodebuild` accepts exactly one `-scheme`, so without a
        // shared scheme spanning containers, N packages is N invocations.
        let rendered = Institute.Xcode.Scheme.render(Self.plan)

        #expect(
            rendered.contains(
                #"ReferencedContainer="container:../swift-primitives/swift-dimension-primitives""#
            )
        )
        #expect(
            rendered.contains(
                #"ReferencedContainer="container:../swift-standards/swift-color-standard""#
            )
        )
        #expect(rendered.contains(#"parallelizeBuildables="YES""#))
    }

    @Test
    func `the scheme carries no launch action, which segfaults xcodebuild`() {
        // Asserted at this layer as well as in swift-xcode, because it is this
        // consumer that dies of it: with a LaunchAction present, `xcodebuild
        // build` resolves the graph and then exits 139 with no diagnostic.
        #expect(!Institute.Xcode.Scheme.render(Self.plan).contains("LaunchAction"))
    }

    @Test
    func `references are checkout relative, never absolute`() {
        let rendered = Institute.Xcode.Scheme.render(Self.plan)

        #expect(!rendered.contains("container:/"))
        #expect(!rendered.contains("/Users/"))
    }

    @Test
    func `every buildable becomes one build action entry, in selection order`() {
        let rendered = Institute.Xcode.Scheme.render(Self.plan)
        let entries = rendered.components(separatedBy: "<BuildActionEntry").count - 1

        #expect(entries == Self.plan.buildables.count)

        let dimension = rendered.range(of: "Dimension Primitives")
        let theme = rendered.range(of: "Theme")
        #expect(dimension != nil)
        #expect(theme != nil)
        if let dimension, let theme {
            #expect(dimension.lowerBound < theme.lowerBound)
        }
    }

    @Test
    func `the blueprint is the target name, which is what xcodebuild matches on`() {
        let rendered = Institute.Xcode.Scheme.render(
            .init(
                buildables: [.init(reference: "../a/b", target: "Color Standard")],
                testables: []
            )
        )

        #expect(rendered.contains(#"BlueprintIdentifier="Color Standard""#))
        #expect(rendered.contains(#"BlueprintName="Color Standard""#))
        #expect(rendered.contains(#"BuildableName="Color Standard""#))
    }

    @Test
    func `test targets become real unskipped testables`() {
        let rendered = Institute.Xcode.Scheme.render(Self.plan)

        #expect(rendered.contains("<TestableReference"))
        #expect(rendered.contains(#"skipped="NO""#))
        #expect(rendered.contains("Color Standard Tests"))
    }
}

extension Institute.Xcode.Scheme.Test.`Edge Case` {
    @Test
    func `a single renamed target changes the rendering, which is what makes drift detectable`() {
        // The positive control for the staleness gate. `xcodebuild` silently
        // drops a `BuildableReference` whose blueprint matches no target in
        // its container — a scheme with one fabricated entry among valid ones
        // exits 0 and prints `** BUILD SUCCEEDED **` having never built that
        // package; only an entirely unmatched scheme fails, with exit 66. So
        // drift between a manifest and the scheme does not fail a build, it
        // shrinks it. If this rendering did not change, the byte-comparison
        // in `current(_:at:)` would report a stale scheme as current and the
        // gate would be decorative.
        let declared = Institute.Xcode.Scheme.render(
            .init(
                buildables: [
                    .init(reference: "../swift-foundations/swift-color", target: "Color")
                ],
                testables: []
            )
        )
        let renamed = Institute.Xcode.Scheme.render(
            .init(
                buildables: [
                    .init(reference: "../swift-foundations/swift-color", target: "Colour")
                ],
                testables: []
            )
        )

        #expect(declared != renamed)
    }

    @Test
    func `a dropped package changes the rendering`() {
        let full = Institute.Xcode.Scheme.render(
            .init(
                buildables: [
                    .init(reference: "../a/one", target: "One"),
                    .init(reference: "../a/two", target: "Two"),
                ],
                testables: []
            )
        )
        let short = Institute.Xcode.Scheme.render(
            .init(
                buildables: [.init(reference: "../a/one", target: "One")],
                testables: []
            )
        )

        #expect(full != short)
    }

    @Test
    func `an empty selection renders a scheme with no buildables rather than failing`() {
        let rendered = Institute.Xcode.Scheme.render(.init(buildables: [], testables: []))

        #expect(rendered.contains("<BuildActionEntries/>"))
    }
}
