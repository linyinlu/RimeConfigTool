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
        try "脚本".write(to: source.appendingPathComponent("custom.lua"), atomically: true, encoding: .utf8)
        try "相同".write(to: source.appendingPathComponent("default.yaml"), atomically: true, encoding: .utf8)
        try Data([1, 2, 3]).write(to: source.appendingPathComponent("cache.bin"))
        let snapshot = try BackupService.create(source: source, destinationFolder: destination)
        precondition(manager.fileExists(atPath: snapshot.appendingPathComponent("sample.dict.yaml").path))
        precondition(!manager.fileExists(atPath: snapshot.appendingPathComponent("cache.bin").path))

        let rime = root.appendingPathComponent("rime")
        try manager.createDirectory(at: rime, withIntermediateDirectories: true)
        try "旧词典".write(to: rime.appendingPathComponent("sample.dict.yaml"), atomically: true, encoding: .utf8)
        try "相同".write(to: rime.appendingPathComponent("default.yaml"), atomically: true, encoding: .utf8)
        let preview = try BackupService.preview(snapshot: snapshot, destination: rime)
        precondition(preview.items.count == 3 && preview.changedCount == 2 && preview.replacementCount == 1)
        let result = try BackupService.restore(preview)
        precondition(result.restoredCount == 2)
        let restoredText = try String(contentsOf: rime.appendingPathComponent("sample.dict.yaml"), encoding: .utf8)
        let previousText = try String(contentsOf: result.previousFilesFolder!.appendingPathComponent("sample.dict.yaml"), encoding: .utf8)
        precondition(restoredText == "词典" && previousText == "旧词典")
        precondition(!manager.fileExists(atPath: rime.appendingPathComponent("备份说明.txt").path))

        let identical = try BackupService.preview(snapshot: snapshot, destination: rime)
        precondition(identical.changedCount == 0)
        let unchangedResult = try BackupService.restore(identical)
        precondition(unchangedResult.restoredCount == 0)

        let stale = try BackupService.preview(snapshot: snapshot, destination: rime)
        try "其他程序修改".write(to: rime.appendingPathComponent("sample.dict.yaml"), atomically: true, encoding: .utf8)
        do {
            _ = try BackupService.restore(stale)
            preconditionFailure("恢复应拒绝预览后发生的外部修改")
        } catch BackupServiceError.changedSincePreview { }

        try manager.createSymbolicLink(at: snapshot.appendingPathComponent("linked.yaml"), withDestinationURL: source.appendingPathComponent("default.yaml"))
        do {
            _ = try BackupService.preview(snapshot: snapshot, destination: rime)
            preconditionFailure("恢复应拒绝符号链接")
        } catch BackupServiceError.unsafeFile(let name) { precondition(name == "linked.yaml") }
        try manager.removeItem(at: snapshot.appendingPathComponent("linked.yaml"))
        try manager.removeItem(at: rime.appendingPathComponent("custom.lua"))
        try manager.createSymbolicLink(at: rime.appendingPathComponent("custom.lua"), withDestinationURL: root.appendingPathComponent("missing.lua"))
        do {
            _ = try BackupService.preview(snapshot: snapshot, destination: rime)
            preconditionFailure("恢复应拒绝目标目录中的悬空符号链接")
        } catch BackupServiceError.unsafeFile(let name) { precondition(name == "custom.lua") }
        print("Import, backup and restore smoke tests passed")
    }
}
