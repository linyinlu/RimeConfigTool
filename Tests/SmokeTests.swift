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
        print("Import and backup smoke tests passed")
    }
}
