import Foundation

@main
struct GeneralSettingsTests {
    @MainActor
    static func main() throws {
        let files = FileManager.default
        let root = files.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: root) }

        let manager = RimeManager()
        let previousPath = manager.customConfigPath
        defer { manager.customConfigPath = previousPath }
        manager.customConfigPath = root.path
        manager.schemas = [RimeSchema(schemaId: "test", name: "测试", enabled: true)]
        let config = root.appendingPathComponent("default.custom.yaml")

        try "patch:\n  # 手写配置\n".write(to: config, atomically: true, encoding: .utf8)
        manager.saveGeneralSettings(pageSize: 8, hotkey: "Control+Shift+space")
        precondition(manager.errorMessage?.contains("已有手写配置") == true)
        precondition(manager.pageSize == 5)
        precondition(manager.switcherHotkey == "Control+grave")
        precondition(try String(contentsOf: config, encoding: .utf8) == "patch:\n  # 手写配置\n")

        try files.removeItem(at: config)
        manager.saveGeneralSettings(pageSize: 8, hotkey: "Control+Shift+space")
        precondition(manager.pageSize == 8)
        precondition(manager.switcherHotkey == "Control+Shift+space")
        let saved = try String(contentsOf: config, encoding: .utf8)
        precondition(saved.contains("\"menu/page_size\": 8"))
        precondition(saved.contains("Control+Shift+space"))

        manager.saveGeneralSettings(pageSize: 9, hotkey: "invalid key")
        precondition(manager.pageSize == 8)
        precondition(manager.switcherHotkey == "Control+Shift+space")
        print("General settings write consistency tests passed")
    }
}
