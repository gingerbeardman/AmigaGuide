import AppKit
import Foundation

enum GuideThumbnail {
    struct Preview {
        var title: String
        var rawLines: [String]

        func lines(fontSize: CGFloat) -> [NSAttributedString] {
            rawLines.map { GuideThumbnail.attributedLine($0, fontSize: fontSize) }
        }
    }

    static func preview(fromGuideAt url: URL) -> Preview {
        let text = firstChunk(at: url)
        return preview(from: text, fallbackTitle: url.deletingPathExtension().lastPathComponent)
    }

    static func preview(from text: String, fallbackTitle: String) -> Preview {
        var title = fallbackTitle
        var rawLines: [String] = []
        var inNode = false
        for rawLine in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            var line = String(rawLine)
            if line.hasSuffix("\r") { line.removeLast() }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()
            if lower.hasPrefix("@node ") {
                if inNode { break }
                title = nodeTitle(from: trimmed) ?? title
                inNode = true
                continue
            }
            if inNode, lower.hasPrefix("@endnode") { break }
            guard inNode else { continue }
            if trimmed.hasPrefix("@"), !trimmed.hasPrefix("@{") { continue }
            rawLines.append(line)
        }
        while rawLines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            rawLines.removeFirst()
        }
        if rawLines.count > 16 {
            rawLines = Array(rawLines.prefix(16))
        }
        return Preview(title: title, rawLines: rawLines)
    }

    static func draw(_ preview: Preview, in size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        if NSGraphicsContext.current?.isFlipped != true {
            let transform = NSAffineTransform()
            transform.translateX(by: 0, yBy: size.height)
            transform.scaleX(by: 1, yBy: -1)
            transform.concat()
        }

        let s = min(size.width, size.height)
        let window = NSRect(origin: .zero, size: size)
        let bevel = max(1, (s / 128).rounded())
        fillBevelled(window, fill: NSColor(calibratedRed: 0.81, green: 0.81, blue: 0.81, alpha: 1), bevel: bevel, raised: true)

        let inner = window.insetBy(dx: bevel, dy: bevel)
        let titleBarHeight = max(9, min(26, (s * 0.08).rounded()))
        let titleBar = NSRect(x: inner.minX, y: inner.minY, width: inner.width, height: titleBarHeight)
        NSColor(calibratedRed: 0.0, green: 0.33, blue: 0.67, alpha: 1).setFill()
        titleBar.fill()

        let gadgetPad = max(1, (bevel * 0.75).rounded(.up))
        let gadget = max(6, titleBarHeight - gadgetPad * 2)
        if gadget <= titleBar.height - 1 {
            let close = NSRect(x: titleBar.minX + gadgetPad, y: titleBar.minY + gadgetPad, width: gadget, height: gadget)
            drawCloseGadget(close, bevel: max(1, bevel * 0.6))
            let depth = NSRect(x: titleBar.maxX - gadgetPad - gadget, y: titleBar.minY + gadgetPad, width: gadget, height: gadget)
            drawDepthGadget(depth, bevel: max(1, bevel * 0.6))
        }

        let titleFontSize = max(7, titleBarHeight * 0.58)
        let titleFont = NSFont.monospacedSystemFont(ofSize: titleFontSize, weight: .semibold)
        let titlePad = gadget + gadgetPad * 3
        let titleRect = NSRect(
            x: titleBar.minX + titlePad,
            y: titleBar.minY,
            width: max(0, titleBar.width - titlePad * 2),
            height: titleBarHeight
        )
        let titleStyle = NSMutableParagraphStyle()
        titleStyle.alignment = .left
        titleStyle.lineBreakMode = .byTruncatingTail
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.white,
            .paragraphStyle: titleStyle
        ]
        let titleBounds = (preview.title as NSString).boundingRect(
            with: titleRect.size,
            options: .usesLineFragmentOrigin,
            attributes: titleAttrs
        )
        var titleDraw = titleRect
        titleDraw.origin.y += max(0, (titleRect.height - titleBounds.height) / 2)
        drawUpright(NSAttributedString(string: preview.title, attributes: titleAttrs), in: titleDraw)

        NSColor(calibratedWhite: 0, alpha: 0.35).setFill()
        NSRect(x: inner.minX, y: titleBar.maxY, width: inner.width, height: 1).fill()

        let body = NSRect(
            x: inner.minX,
            y: titleBar.maxY + 1,
            width: inner.width,
            height: max(0, inner.maxY - titleBar.maxY - 1)
        )
        guard body.height > 12, s >= 72 else { return }

        let fontSize = max(6, min(12, body.width / 22))
        let lines = preview.lines(fontSize: fontSize)
        let leading = fontSize * 1.22
        var y = body.minY + max(3, bevel * 2)
        let x = body.minX + max(3, bevel * 2)
        let width = body.width - max(6, bevel * 4)
        for line in lines {
            if y + leading > body.maxY - 2 { break }
            let rect = NSRect(x: x, y: y, width: width, height: leading)
            drawUpright(line, in: rect)
            y += leading
        }
    }

    static func nodeTitle(from line: String) -> String? {
        if let start = line.firstIndex(of: "\""),
           let end = line[line.index(after: start)...].firstIndex(of: "\"") {
            let title = String(line[line.index(after: start)..<end])
                .trimmingCharacters(in: .whitespaces)
            return title.isEmpty ? nil : title
        }
        var rest = line
        if let at = rest.range(of: "@node ", options: .caseInsensitive) {
            rest = String(rest[at.upperBound...])
        }
        rest = rest.trimmingCharacters(in: .whitespaces)
        return rest.split(whereSeparator: \.isWhitespace).first.map(String.init)
    }
}

private extension GuideThumbnail {
    static func firstChunk(at url: URL) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }
        let data = handle.readData(ofLength: 16_384)
        return String(data: data, encoding: .isoLatin1)
            ?? String(decoding: data, as: UTF8.self)
    }

    static func attributedLine(_ line: String, fontSize: CGFloat) -> NSAttributedString {
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let bold = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
        let linkColor = NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.73, alpha: 1)
        let result = NSMutableAttributedString()
        var index = line.startIndex
        var boldOn = false
        var underlineOn = false

        func attrs(link: Bool = false) -> [NSAttributedString.Key: Any] {
            var values: [NSAttributedString.Key: Any] = [
                .font: boldOn ? bold : font,
                .foregroundColor: link ? linkColor : NSColor.black
            ]
            if underlineOn || link {
                values[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            return values
        }

        while index < line.endIndex {
            if line[index...].hasPrefix("@{") {
                if let close = line[index...].firstIndex(of: "}") {
                    let innerStart = line.index(index, offsetBy: 2)
                    let inner = String(line[innerStart..<close])
                    index = line.index(after: close)
                    if inner.hasPrefix("\"") {
                        var label = inner.dropFirst()
                        if let endQuote = label.firstIndex(of: "\"") {
                            label = label[..<endQuote]
                        }
                        let text = label.trimmingCharacters(in: .whitespaces)
                        if !text.isEmpty {
                            result.append(NSAttributedString(string: text, attributes: attrs(link: true)))
                        }
                    } else {
                        switch inner.trimmingCharacters(in: .whitespaces).lowercased() {
                        case "b": boldOn = true
                        case "ub": boldOn = false
                        case "u": underlineOn = true
                        case "uu": underlineOn = false
                        default: break
                        }
                    }
                    continue
                }
            }
            result.append(NSAttributedString(string: String(line[index]), attributes: attrs()))
            index = line.index(after: index)
        }
        return result
    }

    static func drawUpright(_ attributed: NSAttributedString, in rect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: 0, yBy: rect.maxY)
        transform.scaleX(by: 1, yBy: -1)
        transform.concat()
        attributed.draw(
            with: NSRect(x: rect.minX, y: 0, width: rect.width, height: rect.height),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        )
        NSGraphicsContext.restoreGraphicsState()
    }

    static func fillBevelled(_ rect: NSRect, fill: NSColor, bevel: CGFloat, raised: Bool) {
        fill.setFill()
        rect.fill()
        let light = NSColor(calibratedWhite: 1, alpha: raised ? 0.75 : 0.2)
        let dark = NSColor(calibratedWhite: 0, alpha: raised ? 0.45 : 0.15)
        let top = raised ? light : dark
        let bottom = raised ? dark : light
        let t = bevel
        top.setFill()
        NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: t).fill()
        NSRect(x: rect.minX, y: rect.minY, width: t, height: rect.height).fill()
        bottom.setFill()
        NSRect(x: rect.minX, y: rect.maxY - t, width: rect.width, height: t).fill()
        NSRect(x: rect.maxX - t, y: rect.minY, width: t, height: rect.height).fill()
    }

    static func drawCloseGadget(_ rect: NSRect, bevel: CGFloat) {
        fillBevelled(rect, fill: NSColor(calibratedRed: 0.81, green: 0.81, blue: 0.81, alpha: 1), bevel: bevel, raised: true)
        let inner = rect.insetBy(dx: rect.width * 0.28, dy: rect.height * 0.28)
        NSColor(calibratedWhite: 0.15, alpha: 0.8).setStroke()
        let path = NSBezierPath(rect: inner)
        path.lineWidth = max(1, bevel)
        path.stroke()
    }

    static func drawDepthGadget(_ rect: NSRect, bevel: CGFloat) {
        let fill = NSColor(calibratedRed: 0.81, green: 0.81, blue: 0.81, alpha: 1)
        let back = rect.offsetBy(dx: rect.width * 0.18, dy: rect.height * 0.18)
            .insetBy(dx: rect.width * 0.08, dy: rect.height * 0.08)
        fillBevelled(back, fill: fill, bevel: bevel, raised: true)
        let front = rect.insetBy(dx: rect.width * 0.12, dy: rect.height * 0.12)
            .offsetBy(dx: -rect.width * 0.06, dy: -rect.height * 0.06)
        fillBevelled(front, fill: fill, bevel: bevel, raised: true)
    }
}
