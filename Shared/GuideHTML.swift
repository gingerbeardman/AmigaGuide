import Foundation

enum GuideHTML {
    struct Node: Equatable, Sendable {
        var id: String
        var name: String
        var title: String
        var innerHTML: String
    }

    /// Turns GuideML's one-file dump into a node-at-a-time document:
    /// only the current section is visible and scrollable.
    static func paginatedDocument(from html: String) -> String {
        var document = rewriteFragments(in: html)
        document = wrapNodes(in: document)
        document = injectPagerStyle(in: document)
        return document
    }

    /// Pages from a paginated GuideML document, in document order.
    static func nodes(in html: String) -> [Node] {
        guard let regex = try? NSRegularExpression(
            pattern: #"<section class="node" id="([^"]+)"(?:\s+data-node="([^"]*)")?>(.*?)</section>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let ns = html as NSString
        return regex.matches(in: html, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard match.numberOfRanges >= 4 else { return nil }
            let id = ns.substring(with: match.range(at: 1))
            let name: String
            if match.range(at: 2).location != NSNotFound, match.range(at: 2).length > 0 {
                name = decodeAttr(ns.substring(with: match.range(at: 2)))
            } else {
                name = id.hasPrefix("page-") ? String(id.dropFirst(5)).replacingOccurrences(of: "_", with: ".") : id
            }
            let innerHTML = ns.substring(with: match.range(at: 3))
            return Node(id: id, name: name, title: title(from: innerHTML, fallbackID: id), innerHTML: innerHTML)
        }
    }

    static func metaContent(named name: String, in html: String) -> String? {
        let pattern = #"<meta\s+name="\#(NSRegularExpression.escapedPattern(for: name))"\s+content="([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: (html as NSString).length)),
              match.numberOfRanges == 2,
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }
        let value = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    /// DiscMaster-style fragment IDs: `page-dowt`, `page-req_view`, `page-1_1`.
    static func fragmentID(_ raw: String) -> String {
        var value = raw
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        value = value.replacingOccurrences(of: "&amp;", with: "&")
        value = value.lowercased()

        var result = "page-"
        var lastWasSeparator = false
        for scalar in value.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                result.unicodeScalars.append(scalar)
                lastWasSeparator = false
            } else if !lastWasSeparator {
                result.append("_")
                lastWasSeparator = true
            }
        }
        while result.hasSuffix("_") {
            result.removeLast()
        }
        if result == "page-" {
            return "page-main"
        }
        return result
    }

    private static func rewriteFragments(in html: String) -> String {
        let pattern = #"href="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }

        let ns = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
        var result = html
        for match in matches.reversed() {
            guard match.numberOfRanges == 2,
                  let full = Range(match.range, in: result),
                  let valueRange = Range(match.range(at: 1), in: result) else { continue }
            let value = String(result[valueRange])
            guard let rewritten = rewrittenHREF(value) else { continue }
            result.replaceSubrange(full, with: "href=\"\(rewritten)\"")
        }
        return result
    }

    private static func title(from innerHTML: String, fallbackID: String) -> String {
        let raw: String
        if let close = innerHTML.range(of: "</a>", options: .caseInsensitive) {
            raw = String(innerHTML[..<close.lowerBound])
        } else if let tag = innerHTML.range(of: "<") {
            raw = String(innerHTML[..<tag.lowerBound])
        } else {
            raw = innerHTML
        }
        let stripped = raw.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        let decoded = stripped
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !decoded.isEmpty {
            return decoded
        }
        let fallback = fallbackID.hasPrefix("page-") ? String(fallbackID.dropFirst(5)) : fallbackID
        return fallback.replacingOccurrences(of: "_", with: " ")
    }

    private static func encodeAttr(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
    }

    private static func decodeAttr(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private static func rewrittenHREF(_ value: String) -> String? {
        if value.hasPrefix("http:") || value.hasPrefix("https:")
            || value.hasPrefix("mailto:") || value.hasPrefix("javascript:")
            || value.hasPrefix("ftp:") {
            return nil
        }
        if value.hasPrefix("#") {
            return "#\(fragmentID(value))"
        }
        if value.contains(":") {
            return nil
        }
        return "#\(fragmentID(value))"
    }

    private static func wrapNodes(in html: String) -> String {
        guard let bodyOpen = rangeAfterBodyOpen(in: html),
              let bodyClose = html.range(of: "</body>", options: [.caseInsensitive, .backwards]) else {
            return html
        }

        let prefix = String(html[html.startIndex..<bodyOpen])
        let inner = String(html[bodyOpen..<bodyClose.lowerBound])
        let suffix = String(html[bodyClose.lowerBound...])

        guard let nameRegex = try? NSRegularExpression(
            pattern: #"<a\s+name="([^"]+)"(?:\s+id="[^"]*")?\s*>"#,
            options: [.caseInsensitive]
        ) else {
            return html
        }

        let nsInner = inner as NSString
        let matches = nameRegex.matches(in: inner, range: NSRange(location: 0, length: nsInner.length))
        guard !matches.isEmpty else { return html }

        var wrapped = ""
        if let first = matches.first, first.range.location > 0 {
            wrapped += nsInner.substring(to: first.range.location)
        }

        for (index, match) in matches.enumerated() {
            let start = match.range.location
            let end = index + 1 < matches.count ? matches[index + 1].range.location : nsInner.length
            var chunk = nsInner.substring(with: NSRange(location: start, length: end - start))
            let rawName = nsInner.substring(with: match.range(at: 1))
            let nodeID = fragmentID(rawName)
            if let tagEnd = chunk.range(of: ">") {
                chunk = String(chunk[chunk.index(after: tagEnd.lowerBound)...])
            }
            wrapped += "<section class=\"node\" id=\"\(nodeID)\" data-node=\"\(encodeAttr(decodeAttr(rawName)))\">"
            wrapped += chunk
            wrapped += "</section>\n"
        }

        return prefix + wrapped + suffix
    }

    private static func rangeAfterBodyOpen(in html: String) -> String.Index? {
        guard let start = html.range(of: "<body", options: .caseInsensitive) else { return nil }
        guard let end = html[start.lowerBound...].range(of: ">") else { return nil }
        return end.upperBound
    }

    private static func injectPagerStyle(in html: String) -> String {
        let style = """
        <style>
        html, body {
          margin: 0;
          background: #cfcfcf;
          color: #000;
          font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
          font-size: 12px;
          line-height: 1.25;
        }
        tt, pre, code, font {
          font-family: inherit;
        }
        .node {
          display: none;
          box-sizing: border-box;
          width: 100%;
          max-width: 56em;
          max-width: 96ch;
          max-height: 620px;
          overflow: auto;
          margin: 0 auto;
          padding: 8px 14px 20px;
        }
        .node:first-of-type { display: block; }
        .node:has(~ .node:target) { display: none; }
        .node:target { display: block; }
        .node:target ~ .node { display: none; }
        .node pre {
          margin: 0.5em 0 0;
          width: 100%;
          max-width: 100%;
          white-space: pre-wrap;
          word-wrap: break-word;
          overflow-wrap: break-word;
        }
        </style>
        """
        if let head = html.range(of: "</head>", options: .caseInsensitive) {
            var document = html
            document.replaceSubrange(head, with: style + "\n</head>")
            return document
        }
        return html
    }
}
