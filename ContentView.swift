import SwiftUI

struct ContentView: View {
    @StateObject private var rimeManager = RimeManager()
    @State private var selectedTab: String = "general"
    
    var body: some View {
        NavigationSplitView {
            // 左侧边栏
            VStack(alignment: .leading, spacing: 0) {
                // 标题
                HStack {
                    Image(systemName: "keyboard")
                        .foregroundColor(.blue)
                    Text("Rime 配置工具")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                
                // 导航列表
                List(selection: $selectedTab) {
                    NavigationLink(value: "general") {
                        Label("基本设置", systemImage: "gearshape")
                    }
                    
                    NavigationLink(value: "schema") {
                        Label("输入方案", systemImage: "list.bullet")
                    }
                    
                    NavigationLink(value: "theme") {
                        Label("主题样式", systemImage: "paintbrush")
                    }
                    
                    NavigationLink(value: "dict") {
                        Label("词库管理", systemImage: "book")
                    }
                }
                .listStyle(.sidebar)
                
                Spacer()
                
                // 底部状态
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                    HStack {
                        Circle()
                            .fill(rimeManager.isRimeInstalled ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(rimeManager.isRimeInstalled ? "Rime 已安装" : "Rime 未安装")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
            .frame(minWidth: 200)
        } detail: {
            // 右侧主内容区域
            Group {
                switch selectedTab {
                case "general":
                    GeneralConfigView(rimeManager: rimeManager)
                case "schema":
                    SchemaManagerView(rimeManager: rimeManager)
                case "theme":
                    ThemeEditorView(rimeManager: rimeManager)
                case "dict":
                    DictManagerView(rimeManager: rimeManager)
                default:
                    GeneralConfigView(rimeManager: rimeManager)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            rimeManager.loadConfigurations()
        }
    }
}

#Preview {
    ContentView()
}
