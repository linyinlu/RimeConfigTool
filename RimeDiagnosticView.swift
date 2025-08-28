import SwiftUI
import Foundation

struct RimeDiagnosticView: View {
    @State private var diagnosticResults: [DiagnosticResult] = []
    @State private var isRunning = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Rime 安装诊断")
                .font(.title2)
                .fontWeight(.semibold)
            
            if isRunning {
                ProgressView("正在检测...")
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                Button("开始诊断") {
                    runDiagnostic()
                }
                .buttonStyle(.borderedProminent)
            }
            
            if !diagnosticResults.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(diagnosticResults) { result in
                            DiagnosticRowView(result: result)
                        }
                    }
                    .padding()
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .frame(maxHeight: 300)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 500, height: 400)
    }
    
    private func runDiagnostic() {
        isRunning = true
        diagnosticResults.removeAll()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let results = performDiagnostic()
            
            DispatchQueue.main.async {
                self.diagnosticResults = results
                self.isRunning = false
            }
        }
    }
    
    private func performDiagnostic() -> [DiagnosticResult] {
        var results: [DiagnosticResult] = []
        let fileManager = FileManager.default
        
        // 检查常见的 Rime 安装位置
        let checkPaths = [
            ("/Library/Input Methods/Squirrel.app", "系统输入法目录"),
            ("/Applications/Squirrel.app", "应用程序目录"),
            ("/Library/Input Methods/", "输入法目录 (扫描)"),
            ("/Applications/", "应用程序目录 (扫描)")
        ]
        
        for (path, description) in checkPaths {
            let exists = fileManager.fileExists(atPath: path)
            
            if path.hasSuffix("/") {
                // 目录扫描
                do {
                    let contents = try fileManager.contentsOfDirectory(atPath: path)
                    let rimeApps = contents.filter {
                        $0.lowercased().contains("squirrel") || $0.contains("鼠须管")
                    }
                    
                    if rimeApps.isEmpty {
                        results.append(DiagnosticResult(
                            title: description,
                            status: .notFound,
                            detail: "未找到 Rime 相关应用"
                        ))
                    } else {
                        results.append(DiagnosticResult(
                            title: description,
                            status: .found,
                            detail: "找到: \(rimeApps.joined(separator: ", "))"
                        ))
                    }
                } catch {
                    results.append(DiagnosticResult(
                        title: description,
                        status: .error,
                        detail: "无法访问目录: \(error.localizedDescription)"
                    ))
                }
            } else {
                // 直接路径检查
                results.append(DiagnosticResult(
                    title: description,
                    status: exists ? .found : .notFound,
                    detail: path
                ))
            }
        }
        
        // 检查用户配置目录
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let rimeUserDir = homeDir.appendingPathComponent("Library/Rime")
        let configExists = fileManager.fileExists(atPath: rimeUserDir.path)
        
        results.append(DiagnosticResult(
            title: "用户配置目录",
            status: configExists ? .found : .notFound,
            detail: rimeUserDir.path
        ))
        
        // 检查当前输入法
        results.append(DiagnosticResult(
            title: "系统输入源",
            status: .info,
            detail: "请在系统偏好设置中检查是否已添加鼠须管输入法"
        ))
        
        return results
    }
}

struct DiagnosticResult: Identifiable {
    let id = UUID()
    let title: String
    let status: DiagnosticStatus
    let detail: String
}

enum DiagnosticStatus {
    case found
    case notFound
    case error
    case info
    
    var color: Color {
        switch self {
        case .found: return .green
        case .notFound: return .red
        case .error: return .orange
        case .info: return .blue
        }
    }
    
    var icon: String {
        switch self {
        case .found: return "checkmark.circle.fill"
        case .notFound: return "xmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

struct DiagnosticRowView: View {
    let result: DiagnosticResult
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: result.status.icon)
                .foregroundColor(result.status.color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                
                Text(result.detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// 添加到 GeneralConfigView 中
extension GeneralConfigView {
    private func showDiagnostic() {
        // 在 GeneralConfigView 中添加一个状态变量
        // @State private var showingDiagnostic = false
        
        // 然后在按钮中调用
        // showingDiagnostic = true
    }
}
