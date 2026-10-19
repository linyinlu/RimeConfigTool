import Foundation
import CoreFoundation

// 仅解析可检查的文本导出；不猜测搜狗、百度的私有二进制词库格式。
struct DictionaryImportResult {
    let entries: [DictEntry]
    let skipped: Int
    let format: String
    let mode: DictionaryImportMode
}

enum DictionaryImportMode: Equatable { case merge, replaceDraft }

enum DictionaryImportError: LocalizedError {
    case unsupportedEncoding
    case noEntries
    case invalidDraft

    var errorDescription: String? {
        switch self {
        case .unsupportedEncoding: return "无法识别文本编码。请从原输入法导出 UTF-8、UTF-16 或 GB18030 文本词库。"
        case .noEntries: return "未找到有效词条。需要“词语 编码 [权重]”的文本列。"
        case .invalidDraft: return "JSON 草稿格式无效；需要本工具导出的词条数组，且每条包含有效的 word、code 和整数 weight。"
        }
    }
}

enum DictionaryImport {
    private struct DraftRow: Decodable {
        let word: String
        let code: String
        let weight: Int
    }

    static func read(_ data: Data) throws -> DictionaryImportResult {
        let encodings: [String.Encoding] = [.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))]
        guard let content = encodings.compactMap({ String(data: data, encoding: $0) }).first else {
            throw DictionaryImportError.unsupportedEncoding
        }
        return try parse(content)
    }

    static func parse(_ text: String) throws -> DictionaryImportResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("[") || trimmed.hasPrefix("{") {
            return try parseDraft(trimmed)
        }
        var entries: [DictEntry] = []
        var skipped = 0
        var inBody = false
        let yaml = text.components(separatedBy: .newlines).contains { $0.trimmingCharacters(in: .whitespaces) == "..." }
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line == "..." { inBody = true; continue }
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix(";") || line == "---" { continue }
            if yaml && !inBody { continue }
            let parts: [String]
            if line.contains("\t") { parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
            else if line.contains(",") { parts = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init) }
            else { parts = line.split(whereSeparator: \.isWhitespace).map(String.init) }
            // 按 Rime 的词语、编码、权重顺序读取。其他导出格式须先转换列顺序。
            guard parts.count >= 2 else { skipped += 1; continue }
            let word = parts[0].trimmingCharacters(in: .whitespaces)
            let code = parts[1].trimmingCharacters(in: .whitespaces)
            guard !word.isEmpty, !code.isEmpty, !word.contains(where: \.isWhitespace), !code.contains(where: \.isWhitespace), !code.contains(":") else { skipped += 1; continue }
            let weight = parts.count > 2 ? Int(parts[2].trimmingCharacters(in: .whitespaces)) ?? 0 : 0
            entries.append(DictEntry(word: word, code: code, weight: weight))
        }
        guard !entries.isEmpty else { throw DictionaryImportError.noEntries }
        return DictionaryImportResult(entries: entries, skipped: skipped, format: yaml ? "Rime YAML" : "文本词库", mode: .merge)
    }

    private static func parseDraft(_ text: String) throws -> DictionaryImportResult {
        guard let data = text.data(using: .utf8),
              let rows = try? JSONDecoder().decode([DraftRow].self, from: data),
              rows.allSatisfy({ row in
                  !row.word.isEmpty && !row.code.isEmpty &&
                  !row.word.contains(where: \.isWhitespace) &&
                  !row.code.contains(where: \.isWhitespace) && !row.code.contains(":")
              }) else { throw DictionaryImportError.invalidDraft }
        let entries = rows.map { DictEntry(word: $0.word, code: $0.code, weight: $0.weight) }
        return DictionaryImportResult(entries: entries, skipped: 0, format: "RimeConfigTool JSON 草稿", mode: .replaceDraft)
    }
}
