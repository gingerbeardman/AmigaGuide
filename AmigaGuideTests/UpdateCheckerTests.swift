import Foundation
import Testing
@testable import AmigaGuide

struct UpdateCheckerTests {
    @Test func normalizeVersionStripsLeadingV() {
        #expect(UpdateChecker.normalizeVersion("v1.2.3") == "1.2.3")
        #expect(UpdateChecker.normalizeVersion("V2.0") == "2.0")
        #expect(UpdateChecker.normalizeVersion("1.0") == "1.0")
    }

    @Test func compareVersionsOrdersComponents() {
        #expect(UpdateChecker.compareVersions("1.10", "1.9") == .orderedDescending)
        #expect(UpdateChecker.compareVersions("1.0", "1.0.0") == .orderedSame)
        #expect(UpdateChecker.compareVersions("1.0.1", "1.0") == .orderedDescending)
        #expect(UpdateChecker.compareVersions("0.9", "1.0") == .orderedAscending)
    }

    @Test func latestReleaseURLPointsAtThisRepo() {
        #expect(UpdateChecker.latestReleaseURL.host == "api.github.com")
        #expect(UpdateChecker.latestReleaseURL.path.contains("gingerbeardman/AmigaGuide"))
        #expect(UpdateChecker.latestReleaseURL.path.hasSuffix("/releases/latest"))
    }
}
