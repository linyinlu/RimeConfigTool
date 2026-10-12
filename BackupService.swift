import Foundation
import CryptoKit

enum BackupServiceError: LocalizedError {
    case invalidSnapshot
    case emptySnapshot
    case invalidDirectory
    case unsafeFile(String)
    case changedSincePreview
    case restoreFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidSnapshot: return "请选择由本工具创建的备份文件夹，不能选择 Rime 配置目录本身。"
        case .emptySnapshot: return "备份文件夹中没有可恢复的 YAML、TXT 或 LUA 文件。"
        case .invalidDirectory: return "备份或 Rime 配置目录不存在，或不是普通文件夹。"
        case .unsafeFile(let name): return "\(name) 不是普通文件；为避免通过链接改写其他位置，已停止操作。"
        case .changedSincePreview: return "预览后备份或当前配置发生变化，请重新选择备份并检查文件列表。"
        case .restoreFailed(let detail): return detail
        }
    }
}

struct BackupRestoreItem: Equatable, Identifiable {
    enum Action: Equatable { case add, replace, identical }

    var id: String { name }
    let name: String
    let action: Action
    let sourceDigest: String
    let destinationDigest: String?
}

struct BackupRestorePreview: Equatable, Identifiable {
    var id: URL { snapshot }
    let snapshot: URL
    let destination: URL
    let items: [BackupRestoreItem]

    var changedCount: Int { items.filter { $0.action != .identical }.count }
    var replacementCount: Int { items.filter { $0.action == .replace }.count }
}

struct BackupRestoreResult {
    let restoredCount: Int
    let previousFilesFolder: URL?
}

enum BackupService {
    private static let noteName = "备份说明.txt"

    static func create(source: URL, destinationFolder: URL) throws -> URL {
        let fm = FileManager.default
        try requireDirectory(source)
        try requireDirectory(destinationFolder)
        let files = try supportedFiles(in: source)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let folder = destinationFolder.appendingPathComponent("RimeConfigTool-\(stamp)-\(UUID().uuidString.prefix(6))", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: false)
        do {
            for file in files { try fm.copyItem(at: file, to: folder.appendingPathComponent(file.lastPathComponent)) }
            try "备份内容：Rime 用户目录顶层的 YAML、TXT、LUA 文件。未包含自动学习的二进制词库和子目录。恢复前请退出输入法并自行核对文件。\n"
                .write(to: folder.appendingPathComponent(noteName), atomically: true, encoding: .utf8)
            return folder
        } catch {
            try? fm.removeItem(at: folder)
            throw error
        }
    }

    static func preview(snapshot: URL, destination: URL) throws -> BackupRestorePreview {
        try requireDirectory(snapshot)
        try requireDirectory(destination)
        let snapshotURL = snapshot.standardizedFileURL.resolvingSymlinksInPath()
        let destinationURL = destination.standardizedFileURL.resolvingSymlinksInPath()
        let noteURL = snapshotURL.appendingPathComponent(noteName)
        guard snapshotURL != destinationURL,
              try isRegularFile(noteURL),
              try String(contentsOf: noteURL, encoding: .utf8).hasPrefix("备份内容：Rime 用户目录顶层") else {
            throw BackupServiceError.invalidSnapshot
        }
        let files = try supportedFiles(in: snapshotURL)
        guard !files.isEmpty else { throw BackupServiceError.emptySnapshot }
        let items = try files.map { file -> BackupRestoreItem in
            let target = destinationURL.appendingPathComponent(file.lastPathComponent)
            let sourceDigest = try digest(file)
            let destinationDigest = try existingDigest(target)
            let action: BackupRestoreItem.Action = destinationDigest == nil ? .add :
                (destinationDigest == sourceDigest ? .identical : .replace)
            return BackupRestoreItem(name: file.lastPathComponent, action: action,
                                     sourceDigest: sourceDigest, destinationDigest: destinationDigest)
        }
        return BackupRestorePreview(snapshot: snapshotURL, destination: destinationURL, items: items)
    }

    static func restore(_ approved: BackupRestorePreview) throws -> BackupRestoreResult {
        // 确认后再次检查两端文件，拒绝覆盖预览期间发生的新修改。
        guard try preview(snapshot: approved.snapshot, destination: approved.destination) == approved else {
            throw BackupServiceError.changedSincePreview
        }
        let changed = approved.items.filter { $0.action != .identical }
        guard !changed.isEmpty else { return BackupRestoreResult(restoredCount: 0, previousFilesFolder: nil) }

        let fm = FileManager.default
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let previous = approved.destination.appendingPathComponent("RimeConfigTool-before-restore-\(stamp)-\(UUID().uuidString.prefix(6))", isDirectory: true)
        try fm.createDirectory(at: previous, withIntermediateDirectories: false)
        var written: [BackupRestoreItem] = []
        do {
            // 先保存全部将被替换的原件，再开始修改目标目录。
            for item in changed where item.action == .replace {
                let original = approved.destination.appendingPathComponent(item.name)
                guard try digest(original) == item.destinationDigest else { throw BackupServiceError.changedSincePreview }
                try fm.copyItem(at: original, to: previous.appendingPathComponent(item.name))
            }
            for item in changed {
                let source = approved.snapshot.appendingPathComponent(item.name)
                let target = approved.destination.appendingPathComponent(item.name)
                guard try digest(source) == item.sourceDigest else { throw BackupServiceError.changedSincePreview }
                if item.action == .add {
                    guard try existingDigest(target) == nil else { throw BackupServiceError.changedSincePreview }
                } else {
                    guard try digest(target) == item.destinationDigest else { throw BackupServiceError.changedSincePreview }
                }
                // .atomic 先写临时文件，再替换目标文件。
                try Data(contentsOf: source).write(to: target, options: .atomic)
                written.append(item)
            }
            return BackupRestoreResult(restoredCount: written.count, previousFilesFolder: previous)
        } catch {
            var rollbackError: Error?
            for item in written.reversed() {
                let target = approved.destination.appendingPathComponent(item.name)
                do {
                    if item.action == .add {
                        try fm.removeItem(at: target)
                    } else {
                        let original = previous.appendingPathComponent(item.name)
                        try Data(contentsOf: original).write(to: target, options: .atomic)
                    }
                } catch { rollbackError = error }
            }
            if let rollbackError {
                throw BackupServiceError.restoreFailed("恢复失败，自动回滚也未全部完成：\(rollbackError.localizedDescription)。原文件保留在 \(previous.path)。")
            }
            throw BackupServiceError.restoreFailed("恢复未完成，已撤销本次写入。恢复前文件保留在 \(previous.path)。原因：\(error.localizedDescription)")
        }
    }

    private static func supportedFiles(in folder: URL) throws -> [URL] {
        let urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        return try urls.filter { url in
            let name = url.lastPathComponent
            guard name != noteName,
                  name.hasSuffix(".yaml") || name.hasSuffix(".txt") || name.hasSuffix(".lua") else { return false }
            guard try isRegularFile(url) else { throw BackupServiceError.unsafeFile(name) }
            return true
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func requireDirectory(_ url: URL) throws {
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: resolved.path),
              attrs[.type] as? FileAttributeType == .typeDirectory else {
            throw BackupServiceError.invalidDirectory
        }
    }

    private static func isRegularFile(_ url: URL) throws -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return false }
        return attrs[.type] as? FileAttributeType == .typeRegular
    }

    private static func digest(_ url: URL) throws -> String {
        guard try isRegularFile(url) else { throw BackupServiceError.unsafeFile(url.lastPathComponent) }
        return SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
    }

    private static func existingDigest(_ url: URL) throws -> String? {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            guard attrs[.type] as? FileAttributeType == .typeRegular else {
                throw BackupServiceError.unsafeFile(url.lastPathComponent)
            }
            return try digest(url)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return nil
        }
    }
}
