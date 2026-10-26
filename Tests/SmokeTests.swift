import Foundation

// 与应用模型保持相同的词条字段，独立验证纯文件逻辑。
struct DictEntry: Identifiable, Hashable {
    let id = UUID()
    var word: String
    var code: String
    var weight: Int
}

@main
struct SmokeTests {
    static func main() throws {
        let imported = try DictionaryImport.parse("---\nname: test\n...\n你好\tnihao\t100\n# 注释\n坏行\n世界\tshijie\n")
        precondition(imported.entries.count == 2)
        precondition(imported.skipped == 1)
        precondition(imported.entries[0].weight == 100)
        precondition(imported.entries[1].weight == 0)

        let schemaText = """
        switches:
          - name: ascii_mode
            states: [ 中文, 英文 ]
          - name: simplification
            states: [ 漢字, 汉字 ]
        engine:
        """
        let switches = SchemaSwitchConfiguration.definitions(in: schemaText)
        precondition(switches.count == 2)
        precondition(switches[0].name == "ascii_mode" && switches[0].states == ["中文", "英文"])
        let defaults = try SchemaSwitchConfiguration.selections(in: "", for: switches)
        precondition(defaults[0] == 0 && defaults[1] == 0)
        let saved = try SchemaSwitchConfiguration.selections(
            in: "patch:\n  \"switches/@0/reset\": 1\n  \"switches/@1/reset\": 1\n",
            for: switches
        )
        precondition(saved[0] == 1 && saved[1] == 1)
        do {
            _ = try SchemaSwitchConfiguration.selections(
                in: "patch:\n  \"switches/@0/reset\": 9\n",
                for: switches
            )
            preconditionFailure("越界的方案状态不应被静默接受")
        } catch SchemaSwitchConfigurationError.invalidReset(index: 0, value: 9) { }

        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = root.appendingPathComponent("source")
        let destination = root.appendingPathComponent("destination")
        try manager.createDirectory(at: source, withIntermediateDirectories: true)
        try manager.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }
        try "词典".write(to: source.appendingPathComponent("sample.dict.yaml"), atomically: true, encoding: .utf8)
        try Data([1, 2, 3]).write(to: source.appendingPathComponent("cache.bin"))
        let snapshot = try BackupService.create(source: source, destinationFolder: destination)
        precondition(manager.fileExists(atPath: snapshot.appendingPathComponent("sample.dict.yaml").path))
        precondition(!manager.fileExists(atPath: snapshot.appendingPathComponent("cache.bin").path))
        print("Import, schema switch, and backup smoke tests passed")
    }
}
