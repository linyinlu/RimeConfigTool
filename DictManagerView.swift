import SwiftUI
import UniformTypeIdentifiers

struct DictManagerView: View {
    @ObservedObject var rimeManager: RimeManager
    @State private var userDictEntries: [DictEntry] = []
    @State private var searchText = ""
    @State private var selectedEntry: DictEntry?
    @State private var showingAddEntry = false
    @State private var showingImportDialog = false
    @State private var showingExportDialog = false
    @State private var showingEditEntry: DictEntry? = nil
    @State private var isLoading = false
    
    var filteredEntries: [DictEntry] {
        if searchText.isEmpty {
            return userDictEntries
        }
        return userDictEntries.filter { entry in
            entry.word.localizedCaseInsensitiveContains(searchText) ||
            entry.code.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                Text("词库管理")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    showingAddEntry = true
                }) {
                    Label("添加词汇", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    importDictionary()
                }) {
                    Label("导入词典", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    exportDictionary()
                }) {
                    Label("导出词典", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    loadUserDict()
                }) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            Divider()
            
            // 搜索栏和统计
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("搜索词汇或编码...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    
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
                
                HStack {
                    Text("共 \(userDictEntries.count) 个词汇")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !searchText.isEmpty {
                        Text("筛选结果: \(filteredEntries.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                                .controlSize(.mini)
                            Text("加载中...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // 词汇列表
            if filteredEntries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text(searchText.isEmpty ? "暂无用户词汇" : "未找到匹配词汇")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if searchText.isEmpty {
                        VStack(spacing: 8) {
                            Text("开始添加你的个人词汇吧！")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button("添加第一个词汇") {
                                showingAddEntry = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredEntries, selection: $selectedEntry) { entry in
                    DictEntryRowView(
                        entry: entry,
                        isSelected: selectedEntry?.id == entry.id,
                        onSelect: { selectedEntry = entry },
                        onEdit: { showingEditEntry = entry },
                        onDelete: { deleteEntry(entry) }
                    )
                }
                .listStyle(.plain)
                .alternatingRowBackgrounds()
            }
            
            Spacer()
            
            // 底部状态栏
            HStack {
                if let selected = selectedEntry {
                    Text("已选择: \(selected.word)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("保存用户词典") {
                    saveUserDict()
                }
                .buttonStyle(.borderedProminent)
                .disabled(userDictEntries.isEmpty)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .sheet(isPresented: $showingAddEntry) {
            AddDictEntryView { entry in
                userDictEntries.append(entry)
            }
        }
        .sheet(item: $showingEditEntry) { entry in
            EditDictEntryView(entry: entry) { updatedEntry in
                if let index = userDictEntries.firstIndex(where: { $0.id == entry.id }) {
                    userDictEntries[index] = updatedEntry
                }
            }
        }
        .fileImporter(
            isPresented: $showingImportDialog,
            allowedContentTypes: [.plainText, .commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .fileExporter(
            isPresented: $showingExportDialog,
            document: DictDocument(entries: userDictEntries),
            contentType: .plainText,
            defaultFilename: "用户词典"
        ) { result in
            handleExport(result)
        }
        .onAppear {
            loadUserDict()
        }
    }
    
    // MARK: - 方法
    private func loadUserDict() {
        isLoading = true
        
        // 从真实的 Rime 配置目录加载词典
        let rimeDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Rime")
        let userDictFile = rimeDir.appendingPathComponent("user.dict.yaml")
        
        DispatchQueue.global(qos: .userInitiated).async {
            var entries: [DictEntry] = []
            
            // 尝试从真实文件加载
            if FileManager.default.fileExists(atPath: userDictFile.path) {
                do {
                    let content = try String(contentsOf: userDictFile)
                    entries = parseUserDict(content)
                } catch {
                    print("加载用户词典失败: \(error)")
                }
            }
            
            // 如果没有真实数据，使用示例数据
            if entries.isEmpty {
                entries = [
                    DictEntry(word: "Claude", code: "claude", weight: 100),
                    DictEntry(word: "Anthropic", code: "anthropic", weight: 90),
                    DictEntry(word: "人工智能", code: "rgzn", weight: 80),
                    DictEntry(word: "机器学习", code: "jqxx", weight: 75),
                    DictEntry(word: "深度学习", code: "sdxx", weight: 70)
                ]
            }
            
            DispatchQueue.main.async {
                self.userDictEntries = entries
                self.isLoading = false
            }
        }
    }
    
    private func parseUserDict(_ content: String) -> [DictEntry] {
        var entries: [DictEntry] = []
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix("---") {
                continue
            }
            
            let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if parts.count >= 2 {
                let word = parts[0]
                let code = parts[1]
                let weight = parts.count > 2 ? Int(parts[2]) ?? 0 : 0
                
                entries.append(DictEntry(word: word, code: code, weight: weight))
            }
        }
        
        return entries
    }
    
    private func importDictionary() {
        showingImportDialog = true
    }
    
    private func exportDictionary() {
        showingExportDialog = true
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                let content = try String(contentsOf: url)
                let importedEntries = parseImportedDict(content, fileExtension: url.pathExtension)
                userDictEntries.append(contentsOf: importedEntries)
            } catch {
                print("导入失败: \(error)")
            }
            
        case .failure(let error):
            print("文件选择失败: \(error)")
        }
    }
    
    private func parseImportedDict(_ content: String, fileExtension: String) -> [DictEntry] {
        var entries: [DictEntry] = []
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            if fileExtension.lowercased() == "csv" {
                let parts = trimmed.components(separatedBy: ",")
                if parts.count >= 2 {
                    let word = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let code = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    let weight = parts.count > 2 ? Int(parts[2].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0 : 0
                    entries.append(DictEntry(word: word, code: code, weight: weight))
                }
            } else {
                // 文本格式：词汇 编码 [权重]
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2 {
                    let word = parts[0]
                    let code = parts[1]
                    let weight = parts.count > 2 ? Int(parts[2]) ?? 0 : 0
                    entries.append(DictEntry(word: word, code: code, weight: weight))
                }
            }
        }
        
        return entries
    }
    
    private func handleExport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("导出成功到: \(url.path)")
        case .failure(let error):
            print("导出失败: \(error)")
        }
    }
    
    private func saveUserDict() {
        // 保存到真实的 Rime 用户词典文件
        let rimeDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Rime")
        let userDictFile = rimeDir.appendingPathComponent("user.dict.yaml")
        
        var yamlContent = """
# Rime 用户词典
# 格式：词汇 编码 [权重]

---
name: user
version: "1.0"
sort: by_weight
use_preset_vocabulary: true
...

"""
        
        for entry in userDictEntries.sorted(by: { $0.weight > $1.weight }) {
            yamlContent += "\(entry.word)\t\(entry.code)"
            if entry.weight > 0 {
                yamlContent += "\t\(entry.weight)"
            }
            yamlContent += "\n"
        }
        
        do {
            try yamlContent.write(to: userDictFile, atomically: true, encoding: .utf8)
            print("用户词典保存成功")
        } catch {
            print("保存用户词典失败: \(error)")
        }
    }
    
    private func deleteEntry(_ entry: DictEntry) {
        userDictEntries.removeAll { $0.id == entry.id }
    }
}

// MARK: - 词汇行视图
struct DictEntryRowView: View {
    let entry: DictEntry
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.word)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    Text(entry.code)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("权重: \(entry.weight)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("编辑")
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("删除")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - 添加词汇视图
struct AddDictEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var word = ""
    @State private var code = ""
    @State private var weight = 0
    
    let onAdd: (DictEntry) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("添加词汇")
                .font(.title2)
                .fontWeight(.semibold)
            
            Form {
                Section("词汇信息") {
                    TextField("词汇", text: $word)
                        .help("要添加的词汇")
                    
                    TextField("编码", text: $code)
                        .help("拼音或其他输入编码")
                    
                    HStack {
                        Text("权重")
                        Spacer()
                        TextField("权重", value: $weight, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    .help("权重越高，词汇越容易被选中")
                }
                
                Section("预览") {
                    HStack {
                        Text("预览")
                        Spacer()
                        if !word.isEmpty && !code.isEmpty {
                            Text("\(word) [\(code)]")
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("添加") {
                    let entry = DictEntry(word: word, code: code, weight: weight)
                    onAdd(entry)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(word.isEmpty || code.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 350)
    }
}

// MARK: - 编辑词汇视图
struct EditDictEntryView: View {
    let entry: DictEntry
    let onSave: (DictEntry) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var word: String
    @State private var code: String
    @State private var weight: Int
    
    init(entry: DictEntry, onSave: @escaping (DictEntry) -> Void) {
        self.entry = entry
        self.onSave = onSave
        self._word = State(initialValue: entry.word)
        self._code = State(initialValue: entry.code)
        self._weight = State(initialValue: entry.weight)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("编辑词汇")
                .font(.title2)
                .fontWeight(.semibold)
            
            Form {
                Section("词汇信息") {
                    TextField("词汇", text: $word)
                        .help("要编辑的词汇")
                    
                    TextField("编码", text: $code)
                        .help("拼音或其他输入编码")
                    
                    HStack {
                        Text("权重")
                        Spacer()
                        TextField("权重", value: $weight, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    .help("权重越高，词汇越容易被选中")
                }
                
                Section("预览") {
                    HStack {
                        Text("预览")
                        Spacer()
                        if !word.isEmpty && !code.isEmpty {
                            Text("\(word) [\(code)] - \(weight)")
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("保存") {
                    let updatedEntry = DictEntry(word: word, code: code, weight: weight)
                    onSave(updatedEntry)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(word.isEmpty || code.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 350)
    }
}

// MARK: - 文档类型定义
struct DictDocument: FileDocument {
    let entries: [DictEntry]
    
    static var readableContentTypes: [UTType] = [.plainText]
    
    init(entries: [DictEntry]) {
        self.entries = entries
    }
    
    init(configuration: ReadConfiguration) throws {
        entries = []
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        var content = "# 用户词典导出\n# 格式：词汇 编码 权重\n\n"
        
        for entry in entries {
            content += "\(entry.word)\t\(entry.code)\t\(entry.weight)\n"
        }
        
        return FileWrapper(regularFileWithContents: content.data(using: .utf8) ?? Data())
    }
}

// List样式扩展
extension View {
    func alternatingRowBackgrounds() -> some View {
        self
    }
}

#Preview {
    DictManagerView(rimeManager: RimeManager())
        .frame(width: 900, height: 700)
}
