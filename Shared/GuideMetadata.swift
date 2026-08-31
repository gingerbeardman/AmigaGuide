import Foundation

enum GuideMetadata {
    static let fallbackAuthor = "Amiga Guide"

    static func author(fromGuideAt url: URL) -> String? {
        value(of: "author", in: firstChunk(at: url))
    }

    static func creator(fromGuideAt url: URL) -> String {
        author(fromGuideAt: url) ?? fallbackAuthor
    }

    static func value(of command: String, in text: String) -> String? {
        let needle = "@" + command.lowercased()
        for rawLine in text.split(whereSeparator: \.isNewline) {
            var line = String(rawLine)
            if line.hasSuffix("\r") { line.removeLast() }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()
            guard lower.hasPrefix(needle) else { continue }
            let restStart = trimmed.index(trimmed.startIndex, offsetBy: needle.count)
            var rest = String(trimmed[restStart...])
            if let first = rest.first, !first.isWhitespace, first != "\"" {
                continue
            }
            rest = rest.trimmingCharacters(in: .whitespaces)
            if rest.hasPrefix("\"") {
                rest.removeFirst()
                if let end = rest.firstIndex(of: "\"") {
                    rest = String(rest[..<end])
                }
            }
            rest = rest.trimmingCharacters(in: .whitespaces)
            return rest.isEmpty ? nil : rest
        }
        return nil
    }

    private static func firstChunk(at url: URL) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }
        let data = handle.readData(ofLength: 8192)
        return String(data: data, encoding: .isoLatin1)
            ?? String(decoding: data, as: UTF8.self)
    }
}
