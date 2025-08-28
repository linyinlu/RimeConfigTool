import SwiftUI

struct SchemaManagerView: View {
    @ObservedObject var rimeManager: RimeManager
    @State private var searchText = ""
    
    var filteredSchemas: [RimeSchema] {
        if searchText.isEmpty {
            return rimeManager.schemas
        }
        return rimeManager.schemas.filter { schema in
            schema.name.localizedCaseInsensitiveContains(searchText) ||
            schema.schemaId.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                Text("输入方案管理")
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
            
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索输入方案...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            // 方案列表
            if filteredSchemas.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text(searchText.isEmpty ? "暂无输入方案" : "未找到匹配的方案")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if searchText.isEmpty {
                        Text("请先安装Rime输入法并配置输入方案")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(filteredSchemas.enumerated()), id: \.element.id) { index, schema in
                        SchemaRowView(schema: schema, rimeManager: rimeManager)
                    }
                }
                .listStyle(.plain)
            }
            
            Spacer()
            
            // 底部状态栏
            HStack {
                Text("已启用: \(rimeManager.schemas.filter { $0.enabled }.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("保存并部署") {
                    rimeManager.saveSchemaList(rimeManager.schemas)
                }
                .buttonStyle(.borderedProminent)
                .disabled(rimeManager.isLoading)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
}

struct SchemaRowView: View {
    let schema: RimeSchema
    @ObservedObject var rimeManager: RimeManager
    @State private var showingDetails = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 启用开关
            Toggle("", isOn: Binding(
                get: { schema.enabled },
                set: { newValue in
                    if let index = rimeManager.schemas.firstIndex(where: { $0.id == schema.id }) {
                        rimeManager.schemas[index].enabled = newValue
                    }
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            
            VStack(alignment: .leading, spacing: 4) {
                // 方案名称
                Text(schema.name)
                    .font(.headline)
                    .foregroundColor(schema.enabled ? .primary : .secondary)
                
                // 方案ID
                Text(schema.schemaId)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .opacity(0.8)
                
                // 描述
                if let description = schema.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // 状态指示
            VStack(alignment: .trailing, spacing: 4) {
                if schema.enabled {
                    Label("已启用", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("未启用", systemImage: "circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    showingDetails = true
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("查看详情")
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .sheet(isPresented: $showingDetails) {
            SchemaDetailView(schema: schema)
        }
    }
}

struct SchemaDetailView: View {
    let schema: RimeSchema
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // 基本信息
                VStack(alignment: .leading, spacing: 8) {
                    Text("基本信息")
                        .font(.headline)
                    
                    InfoRow(label: "方案名称", value: schema.name)
                    InfoRow(label: "方案ID", value: schema.schemaId)
                    InfoRow(label: "状态", value: schema.enabled ? "已启用" : "未启用")
                    
                    if let description = schema.description {
                        InfoRow(label: "描述", value: description)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("方案详情")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .textSelection(.enabled)
            
            Spacer()
        }
    }
}

#Preview {
    SchemaManagerView(rimeManager: RimeManager())
        .frame(width: 800, height: 600)
}
