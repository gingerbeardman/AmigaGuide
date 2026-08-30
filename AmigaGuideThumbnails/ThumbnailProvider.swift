import AppKit
import QuickLookThumbnailing

final class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, Error?) -> Void
    ) {
        let fileURL = request.fileURL
        let maxSize = request.maximumSize

        guard GuideMLConverter.looksLikeAmigaGuide(at: fileURL) else {
            handler(nil, CocoaError(.fileReadCorruptFile))
            return
        }
        let title = Self.title(from: fileURL) ?? fileURL.deletingPathExtension().lastPathComponent
        let size = CGSize(
            width: min(maxSize.width, 256),
            height: min(maxSize.height, 256)
        )
        handler(QLThumbnailReply(contextSize: size, currentContextDrawing: {
            Self.draw(title: title, in: size)
            return true
        }), nil)
    }

    private static func title(from url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let data = handle.readData(ofLength: 4096)
        let text = String(data: data, encoding: .isoLatin1) ?? ""
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.lowercased().hasPrefix("@node ") else { continue }
            if let start = line.firstIndex(of: "\""),
               let end = line[line.index(after: start)...].firstIndex(of: "\"") {
                return String(line[line.index(after: start)..<end])
            }
            let rest = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
            return rest.split(separator: " ").first.map(String.init)
        }
        return nil
    }

    private static func draw(title: String, in size: CGSize) {
        NSColor(calibratedRed: 0.81, green: 0.81, blue: 0.81, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: max(9, size.width / 18), weight: .semibold),
            .foregroundColor: NSColor.black,
        ]
        let rect = NSRect(x: 10, y: 10, width: size.width - 20, height: size.height - 20)
        (title as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs)
    }
}
