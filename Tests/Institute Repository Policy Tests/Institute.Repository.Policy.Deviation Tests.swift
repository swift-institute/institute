import Institute_Model
import Testing

@testable import Institute_Repository_Policy

@Suite struct `Institute.Repository.Policy.Deviation metadata` {
    @Test func `timeout-minutes is read beside platforms and embedded-target`() {
        let deviation = Institute.Repository.Policy.Deviation(
            metadata: """
                description: "x"
                platforms: apple
                embedded-target: Core
                timeout-minutes: 75 # the render tests are slow
                readme:
                  family: E
                """
        )
        #expect(deviation.platforms == "apple")
        #expect(deviation.embeddedTarget == "Core")
        #expect(deviation.timeout == "75")
    }

    @Test func `an absent timeout-minutes reads as empty`() {
        #expect(Institute.Repository.Policy.Deviation(metadata: "platforms: linux\n").timeout == "")
    }
}
