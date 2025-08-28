import SwiftUI

struct GeneralConfigView: View {
    @ObservedObject var rimeManager: RimeManager
    @State private var showingRimeDirectory = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                Text("基本设置")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    rimeManager.loadConfigurations()
                }) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Rime状态
                    GroupBox("Rime状态") {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: rimeManager.isRimeInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(rimeManager.isRimeInstalled ? .green : .red)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(rimeManager.isRimeInstalled ? "Rime 已安装" : "Rime 未检测到")
                                        .font(.headline)
                                    
                                    Text(rimeManager.isRimeInstalled ?
                                         "配置目录: ~/Library/Rime" :
                                         "请检查鼠须管是否正确安装")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(spacing: 4) {
                                    Button("重新检测") {
                                        rimeManager.checkRimeInstallation()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    
                                    Button("配置详情") {
                                        showingRimeDirectory = true
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            
                            if !rimeManager.isRimeInstalled {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("检测说明:")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    
                                    Text("• 检查 /Library/Input Methods/Squirrel.app")
                                    Text("• 检查 /Applications/Squirrel.app")
                                    Text("• 检查 ~/Library/Rime 配置目录")
                                    
                                    HStack {
                                        Text("如果已安装但未检测到，请点击")
                                        Button("重新检测") {
                                            rimeManager.checkRimeInstallation()
                                        }
                                        .buttonStyle(.link)
                                        .controlSize(.small)
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                            } else {
                                HStack {
                                    Text("已启用方案: \(rimeManager.schemas.filter { $0.enabled }.count)")
                                    Spacer()
                                    Text("总方案数: \(rimeManager.schemas.count)")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                    }
                    
                    // 快捷操作
                    GroupBox("快捷操作") {
                        VStack(spacing: 12) {
                            HStack {
                                Button(action: {
                                    rimeManager.deployRime()
                                }) {
                                    Label("重新部署", systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(.bordered)
                                .help("重新部署Rime配置")
                                
                                Button(action: {
                                    openRimeConfigDirectory()
                                }) {
                                    Label("打开配置目录", systemImage: "folder")
                                }
                                .buttonStyle(.bordered)
                                .help("打开 ~/Library/Rime 配置目录")
                                
                                Spacer()
                            }
                        }
                        .padding()
                    }
                    
                    // 关于信息
                    GroupBox("关于") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "keyboard")
                                    .font(.title)
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Rime 配置工具")
                                        .font(.headline)
                                    
                                    Text("版本 1.0.0")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            
                            Text("一个用于管理 Rime 输入法配置的可视化工具，支持输入方案管理、主题编辑、词库管理等功能。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(nil)
                        }
                        .padding()
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingRimeDirectory) {
            RimeDirectoryView()
        }
    }
    
    // MARK: - 辅助方法
    private func openRimeConfigDirectory() {
        let rimeConfigURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Rime")
        
        // 如果目录不存在，先创建它
        if !FileManager.default.fileExists(atPath: rimeConfigURL.path) {
            do {
                try FileManager.default.createDirectory(at: rimeConfigURL, withIntermediateDirectories: true)
            } catch {
                print("创建配置目录失败: \(error)")
                return
            }
        }
        
        NSWorkspace.shared.open(rimeConfigURL)
    }
}

struct RimeDirectoryView: View {
    @Environment(\.dismiss) private var dismiss
    private let rimeDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Rime")
    @State private var configFiles: [String] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Rime 配置目录")
                .font(.title2)
                .fontWeight(.semibold)
            
            // 目录路径
            VStack(alignment: .leading, spacing: 8) {
                Text("配置目录位置：")
                    .font(.headline)
                
                Text(rimeDirectory.path)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .textSelection(.enabled)
            }
            
            // 配置文件列表
            VStack(alignment: .leading, spacing: 8) {
                Text("配置文件：")
                    .font(.headline)
                
                if isLoading {
                    ProgressView("扫描配置文件...")
                        .controlSize(.small)
                } else if configFiles.isEmpty {
                    Text("配置目录为空或不存在")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(configFiles, id: \.self) { file in
                                HStack {
                                    Image(systemName: getFileIcon(for: file))
                                        .foregroundColor(getFileColor(for: file))
                                    
                                    Text(file)
                                        .font(.system(.caption, design: .monospaced))
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(height: 120)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                }
            }
            
            // 说明信息
            VStack(alignment: .leading, spacing: 4) {
                Text("重要文件说明：")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text("• default.yaml - 全局配置")
                Text("• squirrel.yaml - 外观主题配置")
                Text("• *.schema.yaml - 输入方案配置")
                Text("• *.dict.yaml - 词典文件")
                Text("• user.dict.yaml - 用户词典")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            HStack {
                Button("在Finder中打开") {
                    NSWorkspace.shared.open(rimeDirectory)
                }
                .buttonStyle(.borderedProminent)
                
                Button("刷新列表") {
                    loadConfigFiles()
                }
                .buttonStyle(.bordered)
                
                Button("关闭") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 500, height: 500)
        .onAppear {
            loadConfigFiles()
        }
    }
    
    private func loadConfigFiles() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var files: [String] = []
            
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: rimeDirectory.path)
                files = contents.filter { file in
                    file.hasSuffix(".yaml") || file.hasSuffix(".yml") || file.hasSuffix(".txt") || file.hasSuffix(".log")
                }.sorted()
            } catch {
                print("扫描配置目录失败: \(error)")
            }
            
            DispatchQueue.main.async {
                self.configFiles = files
                self.isLoading = false
            }
        }
    }
    
    private func getFileIcon(for filename: String) -> String {
        if filename.contains(".schema.") {
            return "keyboard"
        } else if filename.contains(".dict.") || filename == "user.dict.yaml" {
            return "book.closed"
        } else if filename == "default.yaml" {
            return "gearshape"
        } else if filename == "squirrel.yaml" {
            return "paintbrush"
        } else if filename.hasSuffix(".log") {
            return "doc.text"
        } else {
            return "doc"
        }
    }
    
    private func getFileColor(for filename: String) -> Color {
        if filename.contains(".schema.") {
            return .blue
        } else if filename.contains(".dict.") || filename == "user.dict.yaml" {
            return .green
        } else if filename == "default.yaml" {
            return .orange
        } else if filename == "squirrel.yaml" {
            return .purple
        } else if filename.hasSuffix(".log") {
            return .secondary
        } else {
            return .primary
        }
    }
}

#Preview {
    GeneralConfigView(rimeManager: RimeManager())
        .frame(width: 800, height: 600)
}
