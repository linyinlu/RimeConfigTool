import Foundation
import Combine

struct RimeSchema: Identifiable, Hashable {
    var id: String { schemaId }
    var schemaId: String
    var name: String
    var enabled: Bool
    var description: String?
}

struct RimeTheme {
    var name = "默认主题"
    var horizontal = true
    var inlinePreedit = true
    var candidateFormat = "%c\u{2005}%@\u{2005}"
    var cornerRadius = 5.0
    var borderHeight = 4.0
    var borderWidth = 1.0
    var backgroundColor = "0xFFFFFF"
    var borderColor = "0xE0E0E0"
    var textColor = "0x000000"
    var highlightedColor = "0xD75A00"
    var candidateTextColor = "0x000000"
    static let `default` = RimeTheme()
}

struct DictEntry: Identifiable, Hashable {
    let id = UUID()
    var word: String
    var code: String
    var weight: Int
    init(word: String, code: String, weight: Int = 0) {
        self.word = word; self.code = code; self.weight = weight
    }
}

@MainActor
final class RimeManager: ObservableObject {
    @Published var isRimeInstalled = false
    @Published var schemas: [RimeSchema] = []
    @Published var currentTheme = RimeTheme.default
    @Published var pageSize = 5
    @Published var switcherHotkey = "Control+grave"
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var customConfigPath = "" {
        didSet { UserDefaults.standard.set(customConfigPath, forKey: "rimeConfigPath") }
    }

    var rimeUserDir: URL {
        customConfigPath.isEmpty
            ? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Rime")
            : URL(fileURLWithPath: customConfigPath, isDirectory: true)
    }

    init() {
        customConfigPath = UserDefaults.standard.string(forKey: "rimeConfigPath") ?? ""
        checkRimeInstallation()
    }

    func checkRimeInstallation() {
        isRimeInstalled = ["/Library/Input Methods/Squirrel.app", "/Applications/Squirrel.app"].contains {
            FileManager.default.fileExists(atPath: $0)
        }
    }

    func loadConfigurations() {
        errorMessage = nil
        do {
            let defaults = try readIfExists("default.yaml")
            let patch = try readIfExists("default.custom.yaml")
            let enabled = Set(parseSchemaIDs(patch).isEmpty ? parseSchemaIDs(defaults) : parseSchemaIDs(patch))
            pageSize = Int(scalar("menu/page_size", in: patch) ?? scalar("menu/page_size", in: defaults) ?? "5") ?? 5
            switcherHotkey = firstSwitcherHotkey(in: patch) ?? firstSwitcherHotkey(in: defaults) ?? "Control+grave"
            let files = (try? FileManager.default.contentsOfDirectory(at: rimeUserDir, includingPropertiesForKeys: nil)) ?? []
            schemas = files.filter { $0.lastPathComponent.hasSuffix(".schema.yaml") }
                .compactMap { url -> RimeSchema? in
                    let id = String(url.lastPathComponent.dropLast(".schema.yaml".count))
                    guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                    let name = scalar("name", in: content) ?? id
                    return RimeSchema(schemaId: id, name: name, enabled: enabled.contains(id), description: nil)
                }.sorted { $0.name < $1.name }
            let themePatch = try readIfExists("squirrel.custom.yaml")
            var theme = RimeTheme.default
            theme.horizontal = scalar("horizontal", in: themePatch).map { $0 == "true" } ?? theme.horizontal
            theme.inlinePreedit = scalar("inline_preedit", in: themePatch).map { $0 == "true" } ?? theme.inlinePreedit
            theme.candidateFormat = scalar("candidate_format", in: themePatch) ?? theme.candidateFormat
            theme.cornerRadius = Double(scalar("corner_radius", in: themePatch) ?? "") ?? theme.cornerRadius
            theme.borderHeight = Double(scalar("border_height", in: themePatch) ?? "") ?? theme.borderHeight
            theme.borderWidth = Double(scalar("border_width", in: themePatch) ?? "") ?? theme.borderWidth
            theme.backgroundColor = scalar("back_color", in: themePatch) ?? theme.backgroundColor
            theme.borderColor = scalar("border_color", in: themePatch) ?? theme.borderColor
            theme.textColor = scalar("text_color", in: themePatch) ?? theme.textColor
            theme.highlightedColor = scalar("hilited_color", in: themePatch) ?? theme.highlightedColor
            theme.candidateTextColor = scalar("candidate_text_color", in: themePatch) ?? theme.candidateTextColor
            currentTheme = theme
        } catch { errorMessage = error.localizedDescription }
    }

    private func readIfExists(_ name: String) throws -> String {
        let url = rimeUserDir.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? try String(contentsOf: url, encoding: .utf8) : ""
    }

    private func scalar(_ key: String, in text: String) -> String? {
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(key + ":") || trimmed.hasPrefix("\"" + key + "\":") || trimmed.hasPrefix("style/" + key + ":") else { continue }
            return String(trimmed.split(separator: ":", maxSplits: 1).last ?? "").trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }
        return nil
    }

    private func firstSwitcherHotkey(in text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        guard let index = lines.firstIndex(where: { $0.contains("switcher/hotkeys") && $0.trimmingCharacters(in: .whitespaces).hasSuffix(":") }) else { return nil }
        guard index + 1 < lines.count else { return nil }
        let line = lines[index + 1].trimmingCharacters(in: .whitespaces)
        guard line.hasPrefix("- ") else { return nil }
        return String(line.dropFirst(2)).trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
    }

    private func parseSchemaIDs(_ text: String) -> [String] {
        text.components(separatedBy: .newlines).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("- schema:") else { return nil }
            return String(trimmed.dropFirst("- schema:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func writePatch(_ content: String, name: String) throws {
        try FileManager.default.createDirectory(at: rimeUserDir, withIntermediateDirectories: true)
        let destination = rimeUserDir.appendingPathComponent(name)
        // 不覆盖已有的手写配置；用户可以先自行合并或移动原文件。
        if FileManager.default.fileExists(atPath: destination.path),
           !(try String(contentsOf: destination, encoding: .utf8)).hasPrefix("# Managed by RimeConfigTool\n") {
            throw NSError(domain: "RimeConfigTool", code: 1, userInfo: [NSLocalizedDescriptionKey: "已有手写配置 \(name)，请先备份并合并后再保存"])
        }
        // 写入前保留上一版本。
        if FileManager.default.fileExists(atPath: destination.path) {
            let backup = rimeUserDir.appendingPathComponent(name + ".backup")
            if FileManager.default.fileExists(atPath: backup.path) { try FileManager.default.removeItem(at: backup) }
            try FileManager.default.copyItem(at: destination, to: backup)
        }
        try ("# Managed by RimeConfigTool\n" + content).write(to: destination, atomically: true, encoding: .utf8)
    }

    func saveSchemaList(_ items: [RimeSchema]) {
        guard items.contains(where: { $0.enabled }) else { errorMessage = "至少启用一个输入方案"; return }
        let list = items.filter(\.enabled).map { "    - schema: \($0.schemaId)" }.joined(separator: "\n")
        do {
            try writePatch("patch:\n  schema_list:\n\(list)\n  \"menu/page_size\": \(pageSize)\n  \"switcher/hotkeys\":\n    - \"\(switcherHotkey)\"\n", name: "default.custom.yaml")
            schemas = items
            deployRime()
        } catch { errorMessage = error.localizedDescription }
    }

    func saveGeneralSettings(pageSize: Int, hotkey: String) {
        guard (1...9).contains(pageSize) else { errorMessage = "每页候选数须为 1 至 9"; return }
        let parts = hotkey.split(separator: "+").map(String.init)
        let modifiers = Set(["Control", "Shift", "Alt"])
        guard parts.count >= 2, parts.dropLast().allSatisfy({ modifiers.contains($0) }),
              parts.last?.range(of: "^[A-Za-z0-9_]+$", options: .regularExpression) != nil else {
            errorMessage = "快捷键格式示例：Control+grave 或 Control+Shift+space"; return
        }
        self.pageSize = pageSize
        switcherHotkey = hotkey
        saveSchemaList(schemas)
    }

    func schemaSwitches(for schemaId: String) throws -> [SchemaSwitchSetting] {
        guard schemaId.range(of: "^[A-Za-z0-9_]+$", options: .regularExpression) != nil else { return [] }
        let url = rimeUserDir.appendingPathComponent("\(schemaId).schema.yaml")
        let content = try String(contentsOf: url, encoding: .utf8)
        var active = false
        var items: [SchemaSwitchSetting] = []
        var currentName: String?
        var switchIndex = -1
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "switches:" { active = true; continue }
            if active && !line.hasPrefix(" ") && !trimmed.isEmpty && !trimmed.hasPrefix("#") { break }
            guard active else { continue }
            if trimmed.hasPrefix("- name:") {
                switchIndex += 1
                currentName = String(trimmed.dropFirst("- name:".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("states:"), let name = currentName,
                      let start = trimmed.firstIndex(of: "["), let end = trimmed.lastIndex(of: "]") {
                let labels = trimmed[trimmed.index(after: start)..<end].split(separator: ",").map {
                    String($0).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if labels.count >= 2 { items.append(SchemaSwitchSetting(index: switchIndex, name: name, states: labels)) }
                currentName = nil
            }
        }
        return items
    }

    func saveSchemaSwitches(schemaId: String, selections: [Int: Int]) {
        do {
            let switches = try schemaSwitches(for: schemaId)
            guard !switches.isEmpty, switches.allSatisfy({ selections[$0.index].map { (0..<$0.states.count).contains($0) } ?? false }) else {
                errorMessage = "输入状态设置无效"; return
            }
            let lines = switches.map { "  \"switches/@\($0.index)/reset\": \(selections[$0.index]!)" }.joined(separator: "\n")
            try writePatch("patch:\n\(lines)\n", name: "\(schemaId).custom.yaml")
            deployRime()
        } catch { errorMessage = error.localizedDescription }
    }

    func saveTheme(_ theme: RimeTheme) {
        let values: [(String, String)] = [
            ("horizontal", "\(theme.horizontal)"), ("inline_preedit", "\(theme.inlinePreedit)"),
            ("candidate_format", "\"\(theme.candidateFormat.replacingOccurrences(of: "\"", with: "\\\""))\""),
            ("corner_radius", "\(theme.cornerRadius)"), ("border_height", "\(theme.borderHeight)"),
            ("border_width", "\(theme.borderWidth)"), ("back_color", theme.backgroundColor),
            ("border_color", theme.borderColor), ("text_color", theme.textColor),
            ("hilited_color", theme.highlightedColor), ("candidate_text_color", theme.candidateTextColor)
        ]
        let lines = values.map { "  style/\($0.0): \($0.1)" }.joined(separator: "\n")
        do {
            try writePatch("patch:\n\(lines)\n", name: "squirrel.custom.yaml")
            currentTheme = theme
            deployRime()
        } catch { errorMessage = error.localizedDescription }
    }

    func deployRime() {
        let candidates = ["/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel", "/Applications/Squirrel.app/Contents/MacOS/Squirrel"]
        guard let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            errorMessage = "未找到鼠须管可执行文件，请在输入法菜单中手动重新部署"
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--reload"]
        do { try process.run() } catch { errorMessage = error.localizedDescription }
    }
}
