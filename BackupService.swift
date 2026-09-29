import Foundation

enum BackupService {
    static func create(source: URL, destinationFolder: URL) throws -> URL {
        let fm = FileManager.default
        let files = try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isRegularFileKey])
            .filter { url in
                let name = url.lastPathComponent
                return name.hasSuffix(".yaml") || name.hasSuffix(".txt") || name.hasSuffix(".lua")
            }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let folder = destinationFolder.appendingPathComponent("RimeConfigTool-\(stamp)-\(UUID().uuidString.prefix(6))", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: false)
        do {
            for file in files { try fm.copyItem(at: file, to: folder.appendingPathComponent(file.lastPathComponent)) }
            try "备份内容：Rime 用户目录顶层的 YAML、TXT、LUA 文件。未包含自动学习的二进制词库和子目录。恢复前请退出输入法并自行核对文件。\n"
                .write(to: folder.appendingPathComponent("备份说明.txt"), atomically: true, encoding: .utf8)
            return folder
        } catch {
            try? fm.removeItem(at: folder)
            throw error
        }
    }
}
