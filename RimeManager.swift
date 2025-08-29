import Foundation
import Combine

// MARK: - 数据模型
struct RimeSchema: Codable, Identifiable, Hashable {
    let id = UUID()
    var schemaId: String
    var name: String
    var enabled: Bool
    var description: String?
    
    enum CodingKeys: String, CodingKey {
        case schemaId = "schema_id"
        case name, enabled, description
    }
}

struct RimeTheme: Codable {
    var name: String
    var horizontal: Bool
    var inlinePreedit: Bool
    var candidateFormat: String
    var cornerRadius: Double
    var borderHeight: Double
    var borderWidth: Double
    var backgroundColor: String
    var borderColor: String
    var textColor: String
    var highlightedColor: String
    var candidateTextColor: String
    
    enum CodingKeys: String, CodingKey {
        case name, horizontal
        case inlinePreedit = "inline_preedit"
        case candidateFormat = "candidate_format"
        case cornerRadius = "corner_radius"
        case borderHeight = "border_height"
        case borderWidth = "border_width"
        case backgroundColor = "back_color"
        case borderColor = "border_color"
        case textColor = "text_color"
        case highlightedColor = "hilited_color"
        case candidateTextColor = "candidate_text_color"
    }
    
    static let `default` = RimeTheme(
        name: "默认主题",
        horizontal: true,
        inlinePreedit: true,
        candidateFormat: "%c\u{2005}%@\u{2005}",
        cornerRadius: 5.0,
        borderHeight: 4.0,
        borderWidth: 1.0,
        backgroundColor: "0xffffff",
        borderColor: "0xE0E0E0",
        textColor: "0x000000",
        highlightedColor: "0xD75A00",
        candidateTextColor: "0x000000"
    )
}

struct DictEntry: Identifiable, Hashable {
    let id = UUID()
    var word: String
    var code: String
    var weight: Int
    
    init(word: String, code: String, weight: Int = 0) {
        self.word = word
        self.code = code
        self.weight = weight
    }
    
    // 使 DictEntry 可变
    mutating func update(word: String? = nil, code: String? = nil, weight: Int? = nil) {
        if let word = word { self.word = word }
        if let code = code { self.code = code }
        if let weight = weight { self.weight = weight }
    }
}

// MARK: - Rime管理器
class RimeManager: ObservableObject {
    @Published var isRimeInstalled = false
    @Published var schemas: [RimeSchema] = []
    @Published var currentTheme: RimeTheme = RimeTheme.default
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var customConfigPath: String = ""
    
    private let fileManager = FileManager.default
    
    // 计算属性：获取正确的 Rime 配置目录
    var rimeUserDir: URL {
        if !customConfigPath.isEmpty {
            return URL(fileURLWithPath: customConfigPath)
        }
        
        // 直接使用用户的真实主目录，避免沙盒化路径
        let realHomeDir = URL(fileURLWithPath: NSHomeDirectory())
        return realHomeDir.appendingPathComponent("Library/Rime")
    }
    
    init() {
        checkRimeInstallation()
    }
    
    // MARK: - 检查Rime安装状态
    func checkRimeInstallation() {
        let fileManager = FileManager.default
        
        // 检查多个可能的 Rime 安装位置
        let possiblePaths = [
            "/Library/Input Methods/Squirrel.app",  // 系统级安装
            "/Applications/Squirrel.app",           // 应用程序文件夹
            rimeUserDir.path                        // 用户配置目录
        ]
        
        var rimeFound = false
        
        for path in possiblePaths {
            if fileManager.fileExists(atPath: path) {
                rimeFound = true
                print("找到 Rime 安装: \(path)")
                break
            }
        }
        
        // 如果找到应用但没有配置目录，创建配置目录
        if rimeFound && !fileManager.fileExists(atPath: rimeUserDir.path) {
            do {
                try fileManager.createDirectory(at: rimeUserDir, withIntermediateDirectories: true)
                print("创建 Rime 配置目录: \(rimeUserDir.path)")
            } catch {
                print("创建配置目录失败: \(error)")
            }
        }
        
        // 也检查是否有任何 .app 文件包含 "Squirrel" 或 "鼠须管"
        if !rimeFound {
            let searchPaths = [
                "/Library/Input Methods/",
                "/Applications/"
            ]
            
            for searchPath in searchPaths {
                do {
                    let contents = try fileManager.contentsOfDirectory(atPath: searchPath)
                    for item in contents {
                        if item.lowercased().contains("squirrel") || item.contains("鼠须管") {
                            rimeFound = true
                            print("找到 Rime 相关应用: \(searchPath)\(item)")
                            break
                        }
                    }
                    if rimeFound { break }
                } catch {
                    // 忽略无法访问的目录
                    continue
                }
            }
        }
        
        isRimeInstalled = rimeFound
        
        if !rimeFound {
            print("未找到 Rime 安装，检查的路径包括:")
            for path in possiblePaths {
                print("- \(path)")
            }
        }
    }
    
    // MARK: - 加载配置
    func loadConfigurations() {
        guard isRimeInstalled else {
            errorMessage = "Rime未安装或配置目录不存在"
            return
        }
        
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.loadSchemas()
            self?.loadTheme()
            
            DispatchQueue.main.async {
                self?.isLoading = false
            }
        }
    }
    
    // MARK: - 加载输入方案
    private func loadSchemas() {
        // 模拟加载一些默认方案
        let defaultSchemas = [
            RimeSchema(schemaId: "luna_pinyin", name: "朙月拼音", enabled: true, description: "基于拼音的输入方案"),
            RimeSchema(schemaId: "luna_pinyin_simp", name: "朙月拼音·简化字", enabled: true, description: "简化字版本的朙月拼音"),
            RimeSchema(schemaId: "double_pinyin", name: "双拼", enabled: false, description: "双拼输入法"),
            RimeSchema(schemaId: "cangjie5", name: "仓颉五代", enabled: false, description: "仓颉输入法第五代"),
            RimeSchema(schemaId: "wubi86", name: "五笔86", enabled: false, description: "五笔字型86版")
        ]
        
        DispatchQueue.main.async {
            self.schemas = defaultSchemas
        }
    }
    
    // MARK: - 加载主题
    private func loadTheme() {
        // 使用默认主题
        DispatchQueue.main.async {
            self.currentTheme = RimeTheme.default
        }
    }
    
    // MARK: - 保存配置
    func saveSchemaList(_ schemas: [RimeSchema]) {
        DispatchQueue.main.async {
            self.schemas = schemas
        }
        deployRime()
    }
    
    func saveTheme(_ theme: RimeTheme) {
        DispatchQueue.main.async {
            self.currentTheme = theme
        }
        deployRime()
    }
    
    // MARK: - 部署Rime
    func deployRime() {
        let possiblePaths = [
            "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel",
            "/Applications/Squirrel.app/Contents/MacOS/Squirrel"
        ]
        
        var squirrelPath: String?
        let fileManager = FileManager.default
        
        for path in possiblePaths {
            if fileManager.fileExists(atPath: path) {
                squirrelPath = path
                break
            }
        }
        
        guard let executablePath = squirrelPath else {
            print("未找到 Squirrel 可执行文件")
            return
        }
        
        print("正在部署 Rime 配置...")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["--reload"]
        
        do {
            try process.run()
            process.waitUntilExit()
            print("Rime 部署完成")
        } catch {
            print("部署Rime失败: \(error)")
        }
    }
}
