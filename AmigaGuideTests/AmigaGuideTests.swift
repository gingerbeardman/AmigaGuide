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
        #expect(html.contains("href=\"http://example.com/guide\""))
        #expect(!html.contains("href=\"http://example.com/guide.\""))
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
        #expect(html.contains("href=\"http://viper.pl/~opus\""))
        #expect(!html.contains("href=\"http://viper.pl/~opus.\""))
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
        #expect(html.contains("max-width: 96ch"))
        #expect(html.contains("ui-monospace"))
        #expect(html.contains("font-size: 12px"))
        #expect(html.contains("font-family: inherit"))
        #expect(!html.contains("<script>"))
        #expect(html.contains("id=\"page-main\""))
        #expect(html.contains("id=\"page-dowt\""))
        #expect(html.contains("data-node=\"main\""))
        #expect(html.contains("data-node=\"dowt\""))
        #expect(html.contains("data-node=\"req&amp;view\""))
    }

    @Test func htmlFileIsUTF8() throws {
        let url = try fixtureURL("Sample.guide")
        let htmlURL = try GuideMLConverter.htmlFile(fromGuideAt: url)
        let text = try String(contentsOf: htmlURL, encoding: .utf8)
        #expect(text.contains("charset=\"utf-8\""))
        #expect(text.contains("Welcome") || text.lowercased().contains("bold"))
    }

    @Test func suggestedHTMLFilenameReplacesGuideExtension() {
        let url = URL(fileURLWithPath: "/tmp/DopusV4.guide")
        #expect(GuideMLConverter.suggestedHTMLFilename(for: url) == "DopusV4.html")
    }

    @Test func suggestedEPUBFilenameReplacesGuideExtension() {
        let url = URL(fileURLWithPath: "/tmp/DopusV4.guide")
        #expect(GuideMLConverter.suggestedEPUBFilename(for: url) == "DopusV4.epub")
    }

    @Test func authorCommandIsReadFromGuide() throws {
        #expect(GuideMetadata.author(fromGuideAt: try fixtureURL("Sample.guide")) == "AmigaGuide")
        #expect(GuideMetadata.author(fromGuideAt: try fixtureURL("GuideML.guide")) == "Chris Young")
        #expect(GuideMetadata.author(fromGuideAt: try fixtureURL("Links.guide")) == nil)
        #expect(GuideMetadata.creator(fromGuideAt: try fixtureURL("Links.guide")) == "Amiga Guide")
        #expect(GuideMetadata.creator(fromGuideAt: try fixtureURL("Sample.guide")) == "AmigaGuide")

        let dopus = URL(fileURLWithPath: "/Users/matt/Downloads/2026-08-29/DopusV4.guide")
        try #require(FileManager.default.fileExists(atPath: dopus.path))
        #expect(GuideMetadata.author(fromGuideAt: dopus) == nil)
        #expect(GuideMetadata.creator(fromGuideAt: dopus) == "Amiga Guide")
    }

    @Test func splitsPaginatedHTMLIntoNodes() throws {
        let html = try GuideMLConverter.htmlString(fromGuideAt: try fixtureURL("Links.guide"))
        let nodes = GuideHTML.nodes(in: html)
        #expect(nodes.map(\.id) == ["page-main", "page-dowt", "page-req_view", "page-config"])
        #expect(nodes.map(\.title) == ["Welcome", "Walk-through", "Requesters", "Configuration"])
        #expect(GuideHTML.metaContent(named: "Author", in: html) == nil)
    }

    @Test func epubSplitsNodesIntoLinkedChapters() throws {
        let html = try GuideMLConverter.htmlString(fromGuideAt: try fixtureURL("Links.guide"))
        let pkg = try GuideEPUB.package(
            html: html,
            title: "Links",
            identifier: "test-links",
            modified: Date(timeIntervalSince1970: 0)
        )

        #expect(pkg.string(named: "mimetype") == "application/epub+zip")
        #expect(pkg.string(named: "META-INF/container.xml")?.contains("EPUB/package.opf") == true)

        let opf = try #require(pkg.string(named: "EPUB/package.opf"))
        #expect(opf.contains("<dc:title>Welcome</dc:title>"))
        #expect(!opf.contains("<dc:title>Links</dc:title>"))
        #expect(opf.contains("<dc:creator>Amiga Guide</dc:creator>"))
        #expect(opf.contains("href=\"cover.xhtml\""))
        #expect(opf.contains("href=\"page-main.xhtml\""))
        #expect(opf.contains("href=\"page-req_view.xhtml\""))
        #expect(opf.contains("properties=\"nav\""))
        #expect(!opf.contains("display: none"))
        let coverRef = try #require(opf.range(of: "idref=\"cover\""))
        let mainRef = try #require(opf.range(of: "idref=\"page-main\""))
        #expect(coverRef.lowerBound < mainRef.lowerBound)

        let nav = try #require(pkg.string(named: "EPUB/nav.xhtml"))
        #expect(nav.contains("href=\"page-dowt.xhtml\">Walk-through</a>"))
        #expect(nav.contains("href=\"page-req_view.xhtml\">Requesters</a>"))
        #expect(!nav.contains("<ol>\n      <ol>"))

        let css = try #require(pkg.string(named: "EPUB/stylesheet.css"))
        #expect(!css.contains("display: none"))
        #expect(!css.contains(":target"))
        #expect(!css.contains("max-width: 60em"))
        #expect(!css.contains("96ch"))
        #expect(!css.contains("overflow-wrap"))
        #expect(css.contains("background: #ffffff"))
        #expect(!css.contains("#cfcfcf"))
        #expect(!css.contains("white-space: pre-wrap"))
        #expect(!css.contains("div.line"))
        #expect(!css.contains("monospace"))
        #expect(!css.contains("Courier"))
        #expect(!css.contains("font-family"))
        #expect(css.contains("h1"))
        #expect(css.contains("text-indent: 0"))
        #expect(css.contains("font-size: 1em"))
        #expect(!css.contains("1.4em"))
        #expect(css.contains("div.cover"))
        #expect(css.contains("18pt"))
        #expect(css.contains("12pt"))
        #expect(!css.contains("24pt"))

        let cover = try #require(pkg.string(named: "EPUB/cover.xhtml"))
        #expect(cover.contains("class=\"cover\""))
        #expect(cover.contains("align=\"center\""))
        #expect(cover.contains("text-align:center"))
        #expect(cover.contains(">Welcome</h1>"))
        #expect(cover.contains("font-size:18pt"))
        #expect(cover.contains("Generated by Amiga Guide"))
        #expect(cover.contains("https://github.com/gingerbeardman/AmigaGuide"))
        #expect(!cover.contains("viewport"))

        let main = try #require(pkg.string(named: "EPUB/page-main.xhtml"))
        let mainBody = chapterBody(main)
        #expect(main.contains("href=\"page-dowt.xhtml\""))
        #expect(main.contains("href=\"page-req_view.xhtml\""))
        #expect(main.contains("href=\"page-config.xhtml\""))
        #expect(mainBody.contains("<ul"))
        #expect(mainBody.contains("<li"))
        #expect(!main.contains("class=\"guide\""))
        #expect(!main.contains("class=\"line\""))
        #expect(!main.contains("<pre"))
        #expect(!main.contains("href=\"#page-dowt\""))
        #expect(!main.lowercased().contains("javascript:"))
        #expect(!main.contains("<script"))
        #expect(main.contains("xmlns=\"http://www.w3.org/1999/xhtml\""))
        #expect(!main.contains("width=device-width"))
        #expect(!main.contains("viewport"))
        #expect(main.contains("<title>Welcome</title>"))
        #expect(!mainBody.contains("Welcome"))
        #expect(!mainBody.contains("Browse"))
        #expect(!mainBody.contains("<hr"))

        let dowt = try #require(pkg.string(named: "EPUB/page-dowt.xhtml"))
        let dowtBody = chapterBody(dowt)
        #expect(dowt.contains("Hello walk"))
        #expect(!dowtBody.contains("Browse"))
        #expect(!dowtBody.contains("Contents"))
        #expect(!dowtBody.contains("Walk-through"))
        #expect(!dowtBody.contains("<hr"))

        let paths = pkg.files.map(\.path)
        #expect(paths.first == "mimetype")
        #expect(paths.contains("EPUB/cover.xhtml"))
        #expect(paths.contains("EPUB/page-dowt.xhtml"))
        #expect(paths.contains("EPUB/page-req_view.xhtml"))
        #expect(paths.contains("EPUB/page-config.xhtml"))
    }

    @Test func epubIncludesAuthorAndPreservesExternalLinks() throws {
        let url = try fixtureURL("GuideML.guide")
        let html = try GuideMLConverter.htmlString(fromGuideAt: url)
        let author = try #require(GuideMetadata.author(fromGuideAt: url))
        let pkg = try GuideEPUB.package(html: html, title: "GuideML", author: author)
        let opf = try #require(pkg.string(named: "EPUB/package.opf"))
        #expect(author == "Chris Young")
        #expect(opf.contains("<dc:creator>Chris Young</dc:creator>"))
        let joined = pkg.files.compactMap { String(data: $0.data, encoding: .utf8) }.joined()
        #expect(joined.contains("href=\"http://www.aminet.net") || joined.contains("href=\"https://github.com/chris-y/guideml"))
        #expect(!joined.lowercased().contains("javascript:"))
        #expect(!joined.contains(".node:target"))
    }

    @Test func writesUnzippableEPUB() throws {
        let html = try GuideMLConverter.htmlString(fromGuideAt: try fixtureURL("Sample.guide"))
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("AmigaGuide-\(UUID().uuidString).epub")
        let unpack = FileManager.default.temporaryDirectory
            .appendingPathComponent("AmigaGuide-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.removeItem(at: unpack)
        }

        try GuideMLConverter.writeEPUB(html, title: "Sample", to: dest)
        let zip = try Data(contentsOf: dest)
        #expect(zip.starts(with: Data([0x50, 0x4B, 0x03, 0x04])))
        let mime = zip.subdata(in: 38..<(38 + 20))
        #expect(String(data: mime, encoding: .ascii) == "application/epub+zip")

        try FileManager.default.createDirectory(at: unpack, withIntermediateDirectories: true)
        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-qq", "-t", dest.path]
        try unzip.run()
        unzip.waitUntilExit()
        #expect(unzip.terminationStatus == 0)

        let extract = Process()
        extract.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        extract.arguments = ["-qq", "-o", dest.path, "-d", unpack.path]
        try extract.run()
        extract.waitUntilExit()
        #expect(extract.terminationStatus == 0)
        #expect(FileManager.default.fileExists(atPath: unpack.appendingPathComponent("EPUB/page-main.xhtml").path))
        #expect(FileManager.default.fileExists(atPath: unpack.appendingPathComponent("EPUB/page-second.xhtml").path))
        let main = try String(
            contentsOf: unpack.appendingPathComponent("EPUB/page-main.xhtml"),
            encoding: .utf8
        )
        #expect(main.contains("href=\"page-second.xhtml\""))
        #expect(main.lowercased().contains("bold"))
        #expect(chapterBody(main).contains("<p"))
        #expect(chapterBody(main).contains("<strong>") || chapterBody(main).contains("<b>"))
        #expect(!chapterBody(main).contains("Browse"))
        #expect(!chapterBody(main).contains("<hr"))
        #expect(!chapterBody(main).contains("class=\"line\""))

        let listing = Pipe()
        let verbose = Process()
        verbose.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        verbose.arguments = ["-v", dest.path]
        verbose.standardOutput = listing
        try verbose.run()
        verbose.waitUntilExit()
        let text = String(data: listing.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        #expect(text.contains("Stored") && text.contains("mimetype"))
        #expect(text.contains("Defl:"))
        #expect(text.contains("page-main.xhtml"))
    }

    @Test func dopusEPUBLinksResolve() throws {
        let url = URL(fileURLWithPath: "/Users/matt/Downloads/2026-08-29/DopusV4.guide")
        try #require(FileManager.default.fileExists(atPath: url.path))
        let html = try GuideMLConverter.htmlString(fromGuideAt: url)
        #expect(GuideMetadata.author(fromGuideAt: url) == nil)
        let pkg = try GuideEPUB.package(
            html: html,
            title: "DopusV4",
            author: GuideMetadata.creator(fromGuideAt: url)
        )
        let opf = try #require(pkg.string(named: "EPUB/package.opf"))
        #expect(opf.contains("<dc:title>Directory Opus Manual</dc:title>"))
        #expect(!opf.contains("<dc:title>DopusV4</dc:title>"))
        #expect(opf.contains("<dc:creator>Amiga Guide</dc:creator>"))
        let main = try #require(pkg.string(named: "EPUB/page-main.xhtml"))
        let mainBody = chapterBody(main)
        #expect(main.contains("href=\"page-dowt.xhtml\""))
        #expect(main.contains("href=\"page-req_view.xhtml\""))
        #expect(main.contains("href=\"page-config.xhtml\""))
        #expect(!main.contains("&#160;"))
        #expect(!main.contains("max-width:60em"))
        #expect(!main.contains("class=\"line\""))
        #expect(mainBody.contains("<h1") || mainBody.contains("<h2"))
        #expect(mainBody.contains("<p"))
        #expect(!mainBody.contains("Browse &gt;"))
        #expect(!mainBody.contains("Browse >"))
        #expect(!mainBody.contains("&lt; Browse"))
        #expect(!mainBody.contains("< Browse"))
        #expect(!mainBody.contains("<hr"))
        #expect(main.contains("<title>"))
        #expect(!mainBody.contains("Directory Opus Manual"))
        let cover = try #require(pkg.string(named: "EPUB/cover.xhtml"))
        #expect(cover.contains(">Directory Opus Manual</h1>"))
        #expect(cover.contains("font-size:18pt"))
        #expect(cover.contains("Generated by Amiga Guide"))
        #expect(cover.contains("https://github.com/gingerbeardman/AmigaGuide"))
        #expect(mainBody.contains("complete manual"))
        #expect(mainBody.contains("GPSoftware"))
        #expect(!mainBody.contains("     "))
        #expect(mainBody.contains("<ul"))
        #expect(pkg.string(named: "EPUB/page-dowt.xhtml") != nil)
        #expect(pkg.string(named: "EPUB/page-req_view.xhtml") != nil)
        let nav = try #require(pkg.string(named: "EPUB/nav.xhtml"))
        #expect(nav.contains("href=\"page-dowt.xhtml\""))
        #expect(nav.contains("<ol>"))
        #expect(nav.contains("Custom Buttons"))
        #expect(nav.contains("Copy"))
        #expect(nav.contains("<span>DOWT</span>") || nav.contains(">DOWT<"))
        #expect(!main.contains("href=\"#page-dowt\""))
        #expect(!main.lowercased().contains("javascript:"))

        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("AmigaGuide-\(UUID().uuidString).epub")
        defer { try? FileManager.default.removeItem(at: dest) }
        try GuideMLConverter.writeEPUB(
            html,
            title: "DopusV4",
            author: GuideMetadata.creator(fromGuideAt: url),
            to: dest
        )
        let epubSize = try dest.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
        #expect(epubSize < html.utf8.count)
        #expect(epubSize < 500_000)
    }

    @Test func writesUTF8HTMLToDisk() throws {
        let html = try GuideMLConverter.htmlString(fromGuideAt: try fixtureURL("Sample.guide"))
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("AmigaGuide-save-\(UUID().uuidString).html")
        defer { try? FileManager.default.removeItem(at: dest) }
        try GuideMLConverter.writeUTF8HTML(html, to: dest)
        let text = try String(contentsOf: dest, encoding: .utf8)
        #expect(text.contains("charset=\"utf-8\""))
        #expect(text.contains("Welcome"))
        #expect(text.contains("<section class=\"node\""))
    }

    @Test func producedHTMLHasNoRemoteResources() throws {
        let html = try GuideMLConverter.htmlString(fromGuideAt: try fixtureURL("Sample.guide"))
        #expect(!html.lowercased().contains("<script"))
        #expect(!html.lowercased().contains("stylesheet"))
        #expect(!html.contains("<img "))
        #expect(!html.contains("src=\"http"))
        #expect(!html.contains("src=\"https"))
        // GuideML attribution and the HTML 4.01 DTD — not loaded as page resources.
        #expect(html.contains("https://www.unsatisfactorysoftware.co.uk"))
        #expect(html.contains("http://www.w3.org/TR/html4/loose.dtd"))
    }

    @Test func guideContentURLsArePreservedAsLinks() throws {
        let html = try GuideMLConverter.htmlString(fromGuideAt: try fixtureURL("GuideML.guide"))
        #expect(html.contains("href=\"http://www.aminet.net"))
        #expect(html.contains("href=\"https://github.com/chris-y/guideml"))
        #expect(html.contains("href=\"http://www.shredzone.de"))
    }

    @Test func displayNameIsAmigaGuideWithASpace() {
        #expect(AppInfo.name == "Amiga Guide")
    }

    @Test func thumbnailPreviewStripsMarkupAndKeepsLinks() throws {
        let preview = GuideThumbnail.preview(fromGuideAt: try fixtureURL("Sample.guide"))
        #expect(preview.title == "Welcome")
        let text = preview.lines(fontSize: 11).map(\.string).joined(separator: "\n")
        #expect(text.contains("bold"))
        #expect(text.contains("Next node"))
        #expect(!text.contains("@{"))
        #expect(!text.contains("@node"))
    }

    @Test func thumbnailPreviewReadsDopusTitleAndLinks() throws {
        let url = URL(fileURLWithPath: "/Users/matt/Downloads/2026-08-29/DopusV4.guide")
        try #require(FileManager.default.fileExists(atPath: url.path))
        let preview = GuideThumbnail.preview(fromGuideAt: url)
        #expect(preview.title == "Directory Opus Manual")
        let text = preview.lines(fontSize: 11).map(\.string).joined(separator: "\n")
        #expect(text.contains("Directory Opus 4 Manual"))
        #expect(text.contains("Copyright Information"))
        #expect(text.contains("System Requirements"))
        #expect(!text.contains("@{"))
    }

    @Test func textEditorIsPlainTextDefaultButNeverXcode() throws {
        let url = try #require(TextEditorApp.url)
        #expect(url.pathExtension == "app")
        let id = Bundle(url: url)?.bundleIdentifier ?? ""
        #expect(id != "com.apple.dt.Xcode")
        #expect(!id.hasPrefix("com.apple.dt.Xcode."))
        #expect(!TextEditorApp.name.isEmpty)
        #expect(TextEditorApp.name != "Xcode")
    }

    @Test func opensOurUTIAndApplesGuideAsAlternate() {
        let ids = AmigaGuideDocument.readableContentTypes.map(\.identifier)
        #expect(ids.contains("com.gingerbeardman.amigaguide"))
        #expect(ids.contains("com.apple.documentation.guide"))

        let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleDocumentTypes") as? [[String: Any]] ?? []
        let owner = types.first {
            ($0["LSItemContentTypes"] as? [String])?.contains("com.gingerbeardman.amigaguide") == true
        }
        let alternate = types.first {
            ($0["LSItemContentTypes"] as? [String])?.contains("com.apple.documentation.guide") == true
        }
        #expect(owner?["LSHandlerRank"] as? String == "Owner")
        #expect(alternate?["LSHandlerRank"] as? String == "Alternate")
        #expect(Bundle.main.object(forInfoDictionaryKey: "UTImportedTypeDeclarations") == nil)

        let exported = Bundle.main.object(forInfoDictionaryKey: "UTExportedTypeDeclarations") as? [[String: Any]] ?? []
        let amiga = exported.first {
            $0["UTTypeIdentifier"] as? String == "com.gingerbeardman.amigaguide"
        }
        let conforms = amiga?["UTTypeConformsTo"] as? [String] ?? []
        #expect(conforms.contains("public.image"))
        #expect(conforms.contains("public.composite-content"))
        #expect(conforms.contains("public.text"))
    }

    @Test func welcomeLinksPointAtSettingsAndGuideML() {
        #expect(AmigaGuideLinks.quickLookSettings.scheme == "x-apple.systempreferences")
        #expect(AmigaGuideLinks.quickLookSettings.absoluteString.contains("ExtensionsPreferences"))
        #expect(!AmigaGuideLinks.quickLookSettings.absoluteString.contains("quicklook"))
        #expect(AmigaGuideLinks.guideML.host == "www.unsatisfactorysoftware.co.uk")
        #expect(AmigaGuideLinks.guideML.absoluteString.contains("guideml"))
        #expect(AmigaGuideLinks.github.host == "github.com")
        #expect(AmigaGuideLinks.github.path.contains("AmigaGuide"))
        #expect(AmigaGuideLinks.guideMLSource == AmigaGuideLinks.github)
        #expect(AmigaGuideLinks.githubReleases.path.contains("AmigaGuide/releases"))
    }

    @Test func convertTwiceDoesNotCrash() throws {
        let url = try fixtureURL("Sample.guide")
        let first = try GuideMLConverter.htmlString(fromGuideAt: url)
        let second = try GuideMLConverter.htmlString(fromGuideAt: url)
        #expect(first == second)
    }

    @Test func epubRebuildsGuideAsSemanticHTML() throws {
        let html = try GuideMLConverter.htmlString(fromGuideAt: try fixtureURL("GuideML.guide"))
        let pkg = try GuideEPUB.package(html: html, title: "GuideML")
        let intro = try #require(pkg.string(named: "EPUB/page-intro.xhtml"))
        let body = chapterBody(intro)
        #expect(body.contains("<h1") || body.contains("<h2"))
        #expect(body.contains("What is GuideML"))
        #expect(body.contains("<p"))
        #expect(body.contains("open source"))
        #expect(body.contains("originally"))
        #expect(!body.contains("class=\"line\""))
        #expect(!body.contains("<pre"))
        #expect(!body.contains("font-family"))
        #expect(!pkg.string(named: "EPUB/stylesheet.css")!.contains("font-family"))
        #expect(!pkg.string(named: "EPUB/stylesheet.css")!.contains("monospace"))
    }

    @Test func htmlKeepsGuideMLNavbar() throws {
        let html = try GuideMLConverter.htmlString(fromGuideAt: try fixtureURL("Links.guide"))
        #expect(html.contains("Browse"))
        #expect(html.contains("<hr"))
    }

    private func chapterBody(_ xhtml: String) -> String {
        guard let start = xhtml.range(of: "<body>"),
              let end = xhtml.range(of: "</body>", options: [.caseInsensitive, .backwards]) else {
            return xhtml
        }
        return String(xhtml[start.upperBound..<end.lowerBound])
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
