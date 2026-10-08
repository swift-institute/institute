import Testing

@testable import Institute_Development
@testable import Institute_Model

@Test
func `A composed root spells a native Windows reference as one escaped Swift literal`() {
    let manifests = [
        Institute.Composed.Manifest(
            reference: #"C:\work\swift-primitives\swift-bit-"primitives""#,
            package: "swift-bit-primitives",
            identity: "swift-bit-primitives",
            libraryProducts: ["Bit Primitives"],
            buildableTargetCount: 1
        )
    ]

    let text = Institute.Composed.Root.render(manifests, swift: "6.4")

    #expect(
        text.contains(#".package(path: "C:\\work\\swift-primitives\\swift-bit-\"primitives\""),"#)
    )
}
