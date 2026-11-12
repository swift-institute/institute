import Institute_CI_Model
public import Institute_Model
import Testing

@Suite
struct ContinuousIntegrationTimeoutTests {
    @Test
    func anAbsentKeyIsTheDefault() throws {
        #expect(try Institute.CI.Timeout(metadata: "") == .default)
        #expect(Institute.CI.Timeout.default.minutes == 40)
    }

    @Test
    func aWholeNumberOfMinutesFromOneTo360IsKept() throws {
        #expect(try Institute.CI.Timeout(metadata: "1").minutes == 1)
        #expect(try Institute.CI.Timeout(metadata: "75").minutes == 75)
        #expect(try Institute.CI.Timeout(metadata: "360").minutes == 360)
    }

    @Test
    func anythingElseIsRefused() {
        for value in ["0", "361", "-5", "+5", "20m", "1.5", " 20", "twenty", "99999999999999999999999"] {
            #expect(throws: Institute.CI.Timeout.Error.invalid(value), "\(value)") {
                try Institute.CI.Timeout(metadata: value)
            }
        }
    }
}
