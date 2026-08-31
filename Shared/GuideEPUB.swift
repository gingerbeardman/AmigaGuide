import Foundation
import zlib

enum GuideEPUB: Sendable {
    struct File: Equatable, Sendable {
        var path: String
        var data: Data
    }

    struct Package: Equatable, Sendable {
        var files: [File]

        func string(named path: String) -> String? {
            files.first { $0.path == path }.flatMap { String(data: $0.data, encoding: .utf8) }
        }
    }

    enum ConversionError: LocalizedError {
        case noChapters
        case invalidXHTML

        var errorDescription: String? {
            switch self {
            case .noChapters:
                return "This AmigaGuide has no pages to save as EPUB."
            case .invalidXHTML:
                return "The converted HTML could not be turned into EPUB."
            }
        }
    }

    nonisolated static func write(
        html: String,
        title: String,
        author: String? = nil,
        to url: URL,
        identifier: String = UUID().uuidString,
        modified: Date = Date()
    ) throws {
        let packed = zipData(from: try package(
            html: html,
            title: title,
            author: author,
            identifier: identifier,
            modified: modified
        ))
        try packed.write(to: url, options: .atomic)
    }

    nonisolated static func package(
        html: String,
        title: String,
        author: String? = nil,
        identifier: String = UUID().uuidString,
        modified: Date = Date()
    ) throws -> Package {
        let nodes = GuideHTML.nodes(in: html)
        guard !nodes.isEmpty else { throw ConversionError.noChapters }

        let bookTitle = titlePageTitle(nodes: nodes, fallback: displayTitle(title))
        let creator = resolvedAuthor(author, html: html)
        var files: [File] = [
            File(path: "mimetype", data: Data("application/epub+zip".utf8)),
            File(path: "META-INF/container.xml", data: Data(containerXML.utf8)),
            File(
                path: "EPUB/package.opf",
                data: Data(opf(
                    title: bookTitle,
                    author: creator,
                    identifier: identifier,
                    modified: modified,
                    nodes: nodes
                ).utf8)
            ),
            File(path: "EPUB/nav.xhtml", data: Data(navXHTML(title: bookTitle, nodes: nodes).utf8)),
            File(path: "EPUB/stylesheet.css", data: Data(stylesheet.utf8)),
            File(path: "EPUB/cover.xhtml", data: Data(coverXHTML(title: bookTitle).utf8))
        ]

        for node in nodes {
            let body = try chapterBody(from: node.innerHTML)
            let xhtml = chapterXHTML(title: node.title, body: body)
            files.append(File(path: "EPUB/\(node.id).xhtml", data: Data(xhtml.utf8)))
        }
        return Package(files: files)
    }

    nonisolated static func zipData(from package: Package) -> Data {
        ZipArchive.data(from: package.files)
    }
}

private extension GuideEPUB {
    static var containerXML: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="EPUB/package.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
    }

    /// Cover is first in the spine so Kobo's RMSDK “publisher CSS on page one”
    /// quirk hits the title page. Sizes live on `div.cover` and inline (`pt`)
    /// because KOReader ignores `body` as parent of DocFragment.
    static var stylesheet: String {
        """
        body {
          margin: 0;
          padding: 0;
          background: #ffffff;
          color: #000000;
          font-size: 1em;
          line-height: 1.4;
        }
        p, li {
          font-size: 1em;
        }
        h1, h2 {
          font-weight: bold;
          font-size: 1em;
          line-height: 1.25;
          margin: 1em 0 0.4em;
        }
        p {
          margin: 0.65em 0;
          text-indent: 0;
        }
        ul {
          margin: 0.65em 0;
          padding-left: 1.5em;
        }
        li { margin: 0.2em 0; }
        div.cover {
          padding: 2em 1em;
          text-align: center;
          width: 100%;
        }
        div.cover h1, div.cover p {
          text-align: center;
          margin-left: auto;
          margin-right: auto;
          width: 100%;
        }
        div.cover h1 {
          font-size: 18pt;
          line-height: 1.2;
          margin-top: 1.5em;
          margin-bottom: 1em;
        }
        div.cover p {
          font-size: 12pt;
          margin-top: 0.8em;
          margin-bottom: 0.8em;
        }
        """
    }

    static var repositoryURL: String { "https://github.com/gingerbeardman/AmigaGuide" }

    static func titlePageTitle(nodes: [GuideHTML.Node], fallback: String) -> String {
        let nodeTitle = nodes.first?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return nodeTitle.isEmpty ? fallback : nodeTitle
    }

    struct TOCItem {
        var title: String
        var id: String?
        var children: [TOCItem] = []
    }

    static func tocTree(from nodes: [GuideHTML.Node]) -> [TOCItem] {
        var roots: [TOCItem] = []
        for node in nodes {
            let parts = node.title
                .split(separator: "/", omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let path = parts.isEmpty ? [node.title] : parts
            insertTOC(&roots, path: path, node: node)
        }
        return roots
    }

    static func insertTOC(_ list: inout [TOCItem], path: [String], node: GuideHTML.Node) {
        let head = path[0]
        let rest = Array(path.dropFirst())
        if let index = list.firstIndex(where: { $0.title == head }) {
            if rest.isEmpty {
                if list[index].id == nil {
                    list[index].id = node.id
                } else {
                    list[index].children.append(TOCItem(title: subsectionLabel(node.name), id: node.id))
                }
            } else {
                insertTOC(&list[index].children, path: rest, node: node)
            }
        } else if rest.isEmpty {
            list.append(TOCItem(title: head, id: node.id))
        } else {
            var parent = TOCItem(title: head)
            insertTOC(&parent.children, path: rest, node: node)
            list.append(parent)
        }
    }

    static func subsectionLabel(_ name: String) -> String {
        let parts = name.split(separator: ".")
        if let last = parts.last, last.contains(where: \.isLetter) || last.contains(where: { !$0.isNumber && $0 != "_" }) {
            return String(last).replacingOccurrences(of: "_", with: " ")
        }
        return name
    }

    static func renderTOC(_ items: [TOCItem], indent: String) -> String {
        items.map { item in
            let label = xmlEscape(item.title)
            let heading: String
            if let id = item.id {
                heading = "<a href=\"\(id).xhtml\">\(label)</a>"
            } else {
                heading = "<span>\(label)</span>"
            }
            if item.children.isEmpty {
                return "\(indent)<li>\(heading)</li>"
            }
            let nested = renderTOC(item.children, indent: indent + "  ")
            return """
            \(indent)<li>
            \(indent)  \(heading)
            \(indent)  <ol>
            \(nested)
            \(indent)  </ol>
            \(indent)</li>
            """
        }.joined(separator: "\n")
    }

    static func displayTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "AmigaGuide" : trimmed
    }

    static func resolvedAuthor(_ author: String?, html: String) -> String {
        let candidates = [author, GuideHTML.metaContent(named: "Author", in: html)]
        for candidate in candidates {
            guard let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { continue }
            return value
        }
        return GuideMetadata.fallbackAuthor
    }

    static func opf(
        title: String,
        author: String?,
        identifier: String,
        modified: Date,
        nodes: [GuideHTML.Node]
    ) -> String {
        let urn = identifier.hasPrefix("urn:uuid:") ? identifier : "urn:uuid:\(identifier)"
        var items = """
            <item id="cover" href="cover.xhtml" media-type="application/xhtml+xml"/>
            <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
            <item id="css" href="stylesheet.css" media-type="text/css"/>
        """
        var spine = "\n    <itemref idref=\"cover\"/>"
        for node in nodes {
            items += "\n    <item id=\"\(xmlNCName(node.id))\" href=\"\(node.id).xhtml\" media-type=\"application/xhtml+xml\"/>"
            spine += "\n    <itemref idref=\"\(xmlNCName(node.id))\"/>"
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid" version="3.0">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:identifier id="bookid">\(xmlEscape(urn))</dc:identifier>
            <dc:title>\(xmlEscape(title))</dc:title>
            <dc:language>en</dc:language>
            <dc:creator>\(xmlEscape(author ?? GuideMetadata.fallbackAuthor))</dc:creator>
            <meta property="dcterms:modified">\(modifiedStamp(modified))</meta>
          </metadata>
          <manifest>
        \(items)
          </manifest>
          <spine>
        \(spine)
          </spine>
        </package>
        """
    }

    static func navXHTML(title: String, nodes: [GuideHTML.Node]) -> String {
        let entries = renderTOC(tocTree(from: nodes), indent: "      ")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="en">
        <head>
          <meta charset="utf-8"/>
          <title>\(xmlEscape(title))</title>
        </head>
        <body>
          <nav epub:type="toc" id="toc">
            <h1>Contents</h1>
            <ol>
        \(entries)
            </ol>
          </nav>
        </body>
        </html>
        """
    }

    static func coverXHTML(title: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="en">
        <head>
          <meta charset="utf-8"/>
          <title>\(xmlEscape(title))</title>
          <link rel="stylesheet" type="text/css" href="stylesheet.css"/>
        </head>
        <body epub:type="cover">
          <div class="cover" align="center" style="text-align:center;width:100%">
            <h1 align="center" style="font-size:18pt;font-weight:bold;text-align:center;width:100%;margin-left:auto;margin-right:auto">\(xmlEscape(title))</h1>
            <p align="center" style="font-size:12pt;text-align:center;width:100%">Generated by Amiga Guide</p>
            <p align="center" style="font-size:12pt;text-align:center;width:100%"><a href="\(repositoryURL)">\(xmlEscape(repositoryURL))</a></p>
          </div>
        </body>
        </html>
        """
    }

    static func chapterXHTML(title: String, body: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
        <head>
          <meta charset="utf-8"/>
          <title>\(xmlEscape(title))</title>
          <link rel="stylesheet" type="text/css" href="stylesheet.css"/>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    static func chapterBody(from innerHTML: String) throws -> String {
        var html = unwrapJavaScriptLinks(in: innerHTML)
        html = rewriteChapterLinks(in: html)
        let wrapped = "<html><body>\(html)</body></html>"
        let document = try XMLDocument(data: Data(wrapped.utf8), options: [.documentTidyHTML])
        guard let body = document.rootElement()?.elements(forName: "body").first else {
            throw ConversionError.invalidXHTML
        }
        stripGuideMLChrome(from: body)
        semantify(body)
        let inner = body.children?.map { $0.xmlString(options: [.nodeCompactEmptyElement]) }.joined() ?? ""
        return compactVoidElements(inner)
    }

    /// GuideML SINGLEFILE emits leftover node title, Contents/Browse/Index,
    /// then `<hr>` before the real page, and another `<hr>` after it.
    /// EPUB already has TOC and next/previous, so drop that chrome.
    static func stripGuideMLChrome(from body: XMLElement) {
        let children = body.children ?? []
        if let firstRule = children.firstIndex(where: isHorizontalRule) {
            for _ in 0...firstRule {
                body.removeChild(at: 0)
            }
        }
        while let last = body.children?.last, isHorizontalRule(last) || isBlankText(last) {
            body.removeChild(at: last.index)
        }
    }

    static func isHorizontalRule(_ node: XMLNode) -> Bool {
        (node as? XMLElement)?.name?.lowercased() == "hr"
    }

    static func isBlankText(_ node: XMLNode) -> Bool {
        node.kind == .text
            && (node.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Rebuild GuideML's pre/tt dump as headings, paragraphs, and lists.
    static func semantify(_ body: XMLElement) {
        let lines = sourceLines(from: body)
        let children = semanticBlocks(from: lines).map(\.element)
        body.setChildren(children.isEmpty ? nil : children)
    }

    static func sourceLines(from body: XMLElement) -> [String] {
        let linearized = linearize(body)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return linearized.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map {
            stripLeadingLayout(String($0))
        }
    }

    static func linearize(_ node: XMLNode) -> String {
        if node.kind == .text {
            return node.stringValue ?? ""
        }
        guard let element = node as? XMLElement else {
            return node.stringValue ?? ""
        }
        let name = element.name?.lowercased() ?? ""
        if name == "br" {
            return "\n"
        }
        if ["a", "b", "i", "u", "strong", "em", "code"].contains(name) {
            return element.xmlString(options: [.nodeCompactEmptyElement])
        }
        let inner = element.children?.map(linearize).joined() ?? element.stringValue ?? ""
        if ["p", "div", "pre", "tt", "font", "blockquote", "h1", "h2", "h3", "li"].contains(name) {
            return inner + "\n"
        }
        return inner
    }

    static func stripLeadingLayout(_ line: String) -> String {
        var index = line.startIndex
        while index < line.endIndex {
            if line[index] == " " || line[index] == "\t" || line[index] == "\u{00A0}" {
                index = line.index(after: index)
                continue
            }
            let rest = line[index...]
            if rest.hasPrefix("&#160;") || rest.hasPrefix("&#xA0;") || rest.hasPrefix("&#xa0;") {
                index = rest.index(index, offsetBy: 6)
                continue
            }
            if rest.hasPrefix("&nbsp;") {
                index = rest.index(index, offsetBy: 6)
                continue
            }
            break
        }
        return String(line[index...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum SemanticBlock {
        case heading(level: Int, xml: String)
        case paragraph(xml: String)
        case list([String])

        var element: XMLElement {
            switch self {
            case .heading(let level, let xml):
                return wrap(level == 1 ? "h1" : "h2", xml)
            case .paragraph(let xml):
                return wrap("p", xml)
            case .list(let items):
                let ul = XMLElement(name: "ul")
                for item in items {
                    ul.addChild(wrap("li", item))
                }
                return ul
            }
        }
    }

    static func semanticBlocks(from lines: [String]) -> [SemanticBlock] {
        var blocks: [SemanticBlock] = []
        var index = 0
        var didHeading = false

        func peekNonBlank(after start: Int) -> String? {
            var i = start
            while i < lines.count {
                if !lines[i].isEmpty { return lines[i] }
                i += 1
            }
            return nil
        }

        while index < lines.count {
            if lines[index].isEmpty {
                index += 1
                continue
            }

            if isLinkOnly(lines[index]) {
                var items: [String] = []
                while index < lines.count {
                    if lines[index].isEmpty {
                        if let next = peekNonBlank(after: index + 1), isLinkOnly(next) {
                            index += 1
                            continue
                        }
                        break
                    }
                    if !isLinkOnly(lines[index]) { break }
                    items.append(normalizeInlineXML(lines[index]))
                    index += 1
                }
                if !items.isEmpty {
                    blocks.append(.list(items))
                }
                continue
            }

            if isBullet(lines[index]) {
                var items: [String] = []
                while index < lines.count {
                    if lines[index].isEmpty {
                        if let next = peekNonBlank(after: index + 1), isBullet(next) {
                            index += 1
                            continue
                        }
                        break
                    }
                    if !isBullet(lines[index]) { break }
                    items.append(normalizeInlineXML(stripBullet(lines[index])))
                    index += 1
                }
                if !items.isEmpty {
                    blocks.append(.list(items))
                }
                continue
            }

            var group: [String] = []
            while index < lines.count, !lines[index].isEmpty, !isLinkOnly(lines[index]), !isBullet(lines[index]) {
                group.append(lines[index])
                index += 1
            }

            if group.count > 1, isHeading(group[0], next: group[1]) {
                let heading = unwrapHeading(group[0])
                let rest = group.dropFirst().map(normalizeInlineXML).filter { !$0.isEmpty }.joined(separator: " ")
                let level = didHeading ? 2 : 1
                didHeading = true
                blocks.append(.heading(level: level, xml: heading))
                if !rest.isEmpty {
                    blocks.append(.paragraph(xml: rest))
                }
                continue
            }

            if group.count == 1, isHeading(group[0], next: peekNonBlank(after: index)) {
                let level = didHeading ? 2 : 1
                didHeading = true
                blocks.append(.heading(level: level, xml: unwrapHeading(group[0])))
                continue
            }

            let paragraph = group.map(normalizeInlineXML).filter { !$0.isEmpty }.joined(separator: " ")
            if !paragraph.isEmpty {
                blocks.append(.paragraph(xml: paragraph))
            }
        }
        return blocks
    }

    static func isLinkOnly(_ xml: String) -> Bool {
        guard xml.lowercased().contains("<a") else { return false }
        let without = xml.replacingOccurrences(
            of: #"<a\b[^>]*>.*?</a>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        return plainText(without).isEmpty
    }

    static func isBullet(_ xml: String) -> Bool {
        let text = plainText(xml)
        return text.hasPrefix("- ") || text.hasPrefix("* ") || text.hasPrefix("• ")
    }

    static func stripBullet(_ xml: String) -> String {
        var line = xml
        for marker in ["- ", "* ", "• "] {
            if let range = line.range(of: marker),
               plainText(String(line[..<range.lowerBound])).isEmpty {
                line.removeSubrange(range)
                break
            }
        }
        return line.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isHeading(_ xml: String, next: String?) -> Bool {
        let text = plainText(xml)
        guard (2...80).contains(text.count), !isLinkOnly(xml), !isBullet(xml) else {
            return false
        }
        if isFullyEmphasized(xml) { return true }
        if let next, let first = plainText(next).first, first.isLowercase {
            return false
        }
        if text.hasSuffix(":") { return true }
        if text.hasSuffix(".") || text.hasSuffix("!") { return false }
        return next != nil
    }

    static func isFullyEmphasized(_ xml: String) -> Bool {
        let trimmed = xml.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^<(b|strong|i|em)>([\s\S]*)</\1>$"#
        return trimmed.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func unwrapHeading(_ xml: String) -> String {
        let trimmed = xml.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^<(b|strong|i|em)>([\s\S]*)</\1>$"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: (trimmed as NSString).length)),
           match.numberOfRanges == 3,
           let inner = Range(match.range(at: 2), in: trimmed) {
            return normalizeInlineXML(String(trimmed[inner]))
        }
        return normalizeInlineXML(trimmed)
    }

    static func plainText(_ xml: String) -> String {
        decodeEntities(
            xml.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        )
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeEntities(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#160;", with: " ")
            .replacingOccurrences(of: "&#xA0;", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
    }

    static func normalizeInlineXML(_ xml: String) -> String {
        let children = fragmentChildren(xml).flatMap(normalizeInline)
        if children.isEmpty { return "" }
        let holder = XMLElement(name: "span")
        for child in children {
            holder.addChild(child)
        }
        trimEdges(of: holder)
        return holder.children?.map { $0.xmlString(options: [.nodeCompactEmptyElement]) }.joined() ?? ""
    }

    static func wrap(_ name: String, _ xml: String) -> XMLElement {
        let element = XMLElement(name: name)
        for child in fragmentChildren(xml).flatMap(normalizeInline) {
            element.addChild(child)
        }
        trimEdges(of: element)
        return element
    }

    static func fragmentChildren(_ xml: String) -> [XMLNode] {
        let trimmed = xml.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        if let doc = try? XMLDocument(xmlString: "<div>\(trimmed)</div>"),
           let children = doc.rootElement()?.children {
            return children.compactMap { $0.copy() as? XMLNode }
        }
        if let doc = try? XMLDocument(data: Data("<div>\(trimmed)</div>".utf8), options: [.documentTidyHTML]) {
            let root = doc.rootElement()
            let div = root?.elements(forName: "body").first?.elements(forName: "div").first
                ?? root?.elements(forName: "div").first
                ?? root
            if let children = div?.children {
                return children.compactMap { $0.copy() as? XMLNode }
            }
        }
        return [textNode(plainText(trimmed))]
    }

    static func normalizeInline(_ node: XMLNode) -> [XMLNode] {
        guard let element = node as? XMLElement else {
            let collapsed = collapseWhitespace(node.stringValue ?? "")
            return collapsed.isEmpty ? [] : [textNode(collapsed)]
        }
        let name = element.name?.lowercased() ?? ""
        if ["font", "tt", "span", "u", "blockquote", "div"].contains(name) {
            return element.children?.flatMap(normalizeInline) ?? []
        }
        let mapped: String
        switch name {
        case "b": mapped = "strong"
        case "i": mapped = "em"
        default: mapped = name
        }
        let out = XMLElement(name: mapped)
        if name == "a" {
            if let href = element.attribute(forName: "href")?.stringValue {
                out.setAttributesWith(["href": href])
            }
        }
        for child in element.children ?? [] {
            for normalized in normalizeInline(child) {
                out.addChild(normalized)
            }
        }
        if out.childCount == 0 { return [] }
        return [out]
    }

    static func trimEdges(of element: XMLElement) {
        while let first = element.children?.first, first.kind == .text {
            let trimmed = (first.stringValue ?? "").replacingOccurrences(
                of: "^\\s+",
                with: "",
                options: .regularExpression
            )
            if trimmed.isEmpty {
                element.removeChild(at: 0)
            } else {
                first.stringValue = trimmed
                break
            }
        }
        while let last = element.children?.last, last.kind == .text {
            let trimmed = (last.stringValue ?? "").replacingOccurrences(
                of: "\\s+$",
                with: "",
                options: .regularExpression
            )
            if trimmed.isEmpty {
                element.removeChild(at: last.index)
            } else {
                last.stringValue = trimmed
                break
            }
        }
    }

    static func collapseWhitespace(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
    }

    static func textNode(_ string: String) -> XMLNode {
        let node = XMLNode(kind: .text)
        node.stringValue = string
        return node
    }

    static func rewriteChapterLinks(in html: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"href="([^"]+)""#) else { return html }
        let ns = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
        var result = html
        for match in matches.reversed() {
            guard match.numberOfRanges == 2,
                  let full = Range(match.range, in: result),
                  let valueRange = Range(match.range(at: 1), in: result) else { continue }
            let value = String(result[valueRange])
            guard value.hasPrefix("#page-") else { continue }
            result.replaceSubrange(full, with: "href=\"\(value.dropFirst()).xhtml\"")
        }
        return result
    }

    static func unwrapJavaScriptLinks(in html: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"<a\s+[^>]*href="javascript:[^"]*"[^>]*>(.*?)</a>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return html
        }
        let ns = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
        var result = html
        for match in matches.reversed() {
            guard let full = Range(match.range, in: result),
                  let inner = Range(match.range(at: 1), in: result) else { continue }
            result.replaceSubrange(full, with: String(result[inner]))
        }
        return result
    }

    static func compactVoidElements(_ xml: String) -> String {
        let voids = ["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "wbr"]
        var result = xml
        for tag in voids {
            let pattern = "<\(tag)(\\s[^>]*)?>\\s*</\(tag)>"
            result = result.replacingOccurrences(
                of: pattern,
                with: "<\(tag)$1/>",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return result
    }

    static func modifiedStamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    static func xmlEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    static func xmlNCName(_ string: String) -> String {
        string.replacingOccurrences(of: #"[^A-Za-z0-9._-]"#, with: "_", options: .regularExpression)
    }
}

private enum ZipArchive {
    static func data(from files: [GuideEPUB.File]) -> Data {
        var local = Data()
        var central = Data()
        var count: UInt16 = 0
        let now = Date()
        let dos = dosDateTime(now)

        for (index, file) in files.enumerated() {
            let nameData = Data(file.path.utf8)
            let crc = crc32(file.data)
            let mustStore = index == 0 && file.path == "mimetype"
            let method: UInt16
            let payload: Data
            if mustStore {
                method = 0
                payload = file.data
            } else if let deflated = deflateRaw(file.data), deflated.count < file.data.count {
                method = 8
                payload = deflated
            } else {
                method = 0
                payload = file.data
            }
            let flags: UInt16 = mustStore ? 0 : 1 << 11
            let offset = UInt32(local.count)

            local.appendLE(UInt32(0x04034b50))
            local.appendLE(UInt16(20))
            local.appendLE(flags)
            local.appendLE(method)
            local.appendLE(dos.time)
            local.appendLE(dos.date)
            local.appendLE(crc)
            local.appendLE(UInt32(payload.count))
            local.appendLE(UInt32(file.data.count))
            local.appendLE(UInt16(nameData.count))
            local.appendLE(UInt16(0))
            local.append(nameData)
            local.append(payload)

            central.appendLE(UInt32(0x02014b50))
            central.appendLE(UInt16(20))
            central.appendLE(UInt16(20))
            central.appendLE(flags)
            central.appendLE(method)
            central.appendLE(dos.time)
            central.appendLE(dos.date)
            central.appendLE(crc)
            central.appendLE(UInt32(payload.count))
            central.appendLE(UInt32(file.data.count))
            central.appendLE(UInt16(nameData.count))
            central.appendLE(UInt16(0))
            central.appendLE(UInt16(0))
            central.appendLE(UInt16(0))
            central.appendLE(UInt16(0))
            central.appendLE(UInt32(0))
            central.appendLE(offset)
            central.append(nameData)

            count += 1
        }

        var out = local
        let centralOffset = UInt32(out.count)
        out.append(central)
        out.appendLE(UInt32(0x06054b50))
        out.appendLE(UInt16(0))
        out.appendLE(UInt16(0))
        out.appendLE(count)
        out.appendLE(count)
        out.appendLE(UInt32(central.count))
        out.appendLE(centralOffset)
        out.appendLE(UInt16(0))
        return out
    }

    /// Raw DEFLATE (no zlib/gzip wrapper), as required by ZIP method 8.
    static func deflateRaw(_ data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }

        var stream = z_stream()
        let initStatus = deflateInit2_(
            &stream,
            Z_BEST_COMPRESSION,
            Z_DEFLATED,
            -MAX_WBITS,
            MAX_MEM_LEVEL,
            Z_DEFAULT_STRATEGY,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard initStatus == Z_OK else { return nil }

        let bound = Int(compressBound(uLong(data.count)))
        var output = Data(count: bound)
        let status = data.withUnsafeBytes { src in
            output.withUnsafeMutableBytes { dst in
                stream.next_in = UnsafeMutablePointer(
                    mutating: src.bindMemory(to: Bytef.self).baseAddress!
                )
                stream.avail_in = uInt(data.count)
                stream.next_out = dst.bindMemory(to: Bytef.self).baseAddress
                stream.avail_out = uInt(bound)
                return zlib.deflate(&stream, Z_FINISH)
            }
        }
        let produced = bound - Int(stream.avail_out)
        deflateEnd(&stream)
        guard status == Z_STREAM_END, produced > 0 else { return nil }
        output.count = produced
        return output
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }

    static let crcTable: [UInt32] = (0..<256).map { i in
        var c = UInt32(i)
        for _ in 0..<8 {
            c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
        }
        return c
    }

    static func dosDateTime(_ date: Date) -> (time: UInt16, date: UInt16) {
        let parts = Calendar(identifier: .gregorian).dateComponents(
            in: TimeZone.current,
            from: date
        )
        let time = UInt16(parts.second! / 2)
            | (UInt16(parts.minute!) << 5)
            | (UInt16(parts.hour!) << 11)
        let year = max(parts.year ?? 1980, 1980)
        let dosDate = UInt16(parts.day!)
            | (UInt16(parts.month!) << 5)
            | (UInt16(year - 1980) << 9)
        return (time, dosDate)
    }
}

private extension Data {
    mutating func appendLE(_ value: UInt16) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }

    mutating func appendLE(_ value: UInt32) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }
}
