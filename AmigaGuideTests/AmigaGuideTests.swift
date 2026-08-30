import Testing
import Foundation
@testable import AmigaGuide

struct AmigaGuideTests {
    @Test func recognisesAmigaGuideMagic() throws {
        let url = try fixtureURL("Sample.guide")
        #expect(GuideMLConverter.looksLikeAmigaGuide(at: url))
    }

    @Test func convertSampleGuideToHTML() throws {
        let url = try fixtureURL("Sample.guide")
        let html = try GuideMLConverter.htmlString(fromGuideAt: url)

        #expect(html.contains("<html>"))
        #expect(html.contains("GuideML"))
        #expect(html.contains("Welcome"))
        #expect(html.contains("Second node"))
        #expect(html.lowercased().contains("<b>bold</b>"))
        #expect(html.lowercased().contains("second"))
    }

    @Test func convertGuideMLDocumentation() throws {
        let url = try fixtureURL("GuideML.guide")
        let html = try GuideMLConverter.htmlString(fromGuideAt: url)

        #expect(html.contains("GuideML 3.17"))
        #expect(html.contains("id=\"page-main\""))
        #expect(html.contains("Disclaimer"))
    }

    @Test func fragmentIDsMatchDiscMasterStyle() {
        #expect(GuideHTML.fragmentID("DOWT") == "page-dowt")
        #expect(GuideHTML.fragmentID("main") == "page-main")
        #expect(GuideHTML.fragmentID("Req&View") == "page-req_view")
        #expect(GuideHTML.fragmentID("req&amp;view") == "page-req_view")
        #expect(GuideHTML.fragmentID("1.1") == "page-1_1")
        #expect(GuideHTML.fragmentID("Config") == "page-config")
    }

    @Test func dopusMainLinksResolve() throws {
        let url = URL(fileURLWithPath: "/Users/matt/Downloads/2026-08-29/DopusV4.guide")
        try #require(FileManager.default.fileExists(atPath: url.path))
        let html = try GuideMLConverter.htmlString(fromGuideAt: url)

        #expect(html.contains("href=\"#page-dowt\""))
        #expect(html.contains("id=\"page-dowt\""))
        #expect(html.contains("href=\"#page-req_view\""))
        #expect(html.contains("id=\"page-req_view\""))
        #expect(html.contains("href=\"#page-config\""))
        #expect(html.contains("id=\"page-config\""))
        #expect(html.contains("href=\"#page-main\""))
        #expect(html.contains("id=\"page-main\""))
        #expect(html.contains("class=\"node\""))
        #expect(!html.contains("href=\"#req&view\""))
    }

    @Test func mixedCaseAndAmpersandLinksResolve() throws {
        let url = try fixtureURL("Links.guide")
        let html = try GuideMLConverter.htmlString(fromGuideAt: url)

        #expect(html.contains("id=\"page-main\""))
        #expect(html.contains("id=\"page-dowt\""))
        #expect(html.contains("id=\"page-req_view\""))
        #expect(html.contains("id=\"page-config\""))
        #expect(html.contains("href=\"#page-dowt\""))
        #expect(html.contains("href=\"#page-req_view\""))
        #expect(html.contains("href=\"#page-config\""))
        #expect(html.contains("href=\"#page-main\""))
        #expect(!html.contains("href=\"#DOWT\""))
        #expect(!html.contains("href=\"#req&view\""))
    }

    @Test func onlyOneSectionIsShown() throws {
        let url = try fixtureURL("Links.guide")
        let html = try GuideMLConverter.htmlString(fromGuideAt: url)
        #expect(html.contains(".node:target"))
        #expect(html.contains("max-height: 620px"))
        #expect(html.contains("-apple-system"))
        #expect(html.contains("font-family: inherit"))
        #expect(!html.contains("<script>"))
        #expect(html.contains("<section class=\"node\" id=\"page-main\">"))
        #expect(html.contains("<section class=\"node\" id=\"page-dowt\">"))
    }

    @Test func htmlFileIsUTF8() throws {
        let url = try fixtureURL("Sample.guide")
        let htmlURL = try GuideMLConverter.htmlFile(fromGuideAt: url)
        let text = try String(contentsOf: htmlURL, encoding: .utf8)
        #expect(text.contains("charset=\"utf-8\""))
        #expect(text.contains("Welcome") || text.lowercased().contains("bold"))
    }

    @Test func displayNameIsAmigaGuideWithASpace() {
        #expect(AppInfo.name == "Amiga Guide")
    }

    @Test func welcomeLinksPointAtSettingsAndGuideML() {
        #expect(AmigaGuideLinks.quickLookSettings.scheme == "x-apple.systempreferences")
        #expect(AmigaGuideLinks.quickLookSettings.absoluteString.contains("ExtensionsPreferences"))
        #expect(!AmigaGuideLinks.quickLookSettings.absoluteString.contains("quicklook"))
        #expect(AmigaGuideLinks.guideML.host == "www.unsatisfactorysoftware.co.uk")
        #expect(AmigaGuideLinks.guideML.absoluteString.contains("guideml"))
        #expect(AmigaGuideLinks.guideMLSource.host == "github.com")
        #expect(AmigaGuideLinks.guideMLSource.path.contains("AmigaGuide"))
    }

    @Test func convertTwiceDoesNotCrash() throws {
        let url = try fixtureURL("Sample.guide")
        let first = try GuideMLConverter.htmlString(fromGuideAt: url)
        let second = try GuideMLConverter.htmlString(fromGuideAt: url)
        #expect(first == second)
    }

    private func fixtureURL(_ name: String) throws -> URL {
        let thisFile = URL(fileURLWithPath: #filePath)
        let url = thisFile
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
        try #require(FileManager.default.fileExists(atPath: url.path))
        return url
    }
}
