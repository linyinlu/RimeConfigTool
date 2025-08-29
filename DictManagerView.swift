import SwiftUI
import UniformTypeIdentifiers

struct DictManagerView: View {
    @ObservedObject var rimeManager: RimeManager
    @State private var userDictEntries: [DictEntry] = []
    @State private var searchText = ""
    @State private var selectedEntry: DictEntry?
    @State private var showingAddEntry = false
    @State private var showingImportDialog = false
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
                
                Button("添加词汇") {
                    showingAddEntry = true
                }
                .buttonStyle(.bordered)
                
                Button("导入词典") {
                    showingImportDialog = true
                }
                .buttonStyle(.bordered)
                
                Button("导出词典") {
                    exportDictionary()
                }
                .buttonStyle(.bordered)
                
                Button("刷新") {
                    loadUserDict()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            Divider()
            
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索词汇或编码...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                
                if !searchText.isEmpty {
                    Button("清除") {
                        searchText = ""
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            
            // 词汇列表
            if filteredEntries.isEmpty {
                VStack {
                    Image(systemName: "book.closed")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text(searchText.isEmpty ? "暂无用户词汇" : "未找到匹配词汇")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if searchText.isEmpty {
                        Button("添加第一个词汇") {
                            showingAddEntry = true
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredEntries) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.word)
                                    .font(.headline)
                                
                                Text("\(entry.code) - 权重: \(entry.weight)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("编辑") {
                                showingEditEntry = entry
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Button("删除") {
                                deleteEntry(entry)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .foregroundColor(.red)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // 底部状态栏
            HStack {
                Text("共 \(userDictEntries.count) 个词汇")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("保存词典") {
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
        .onAppear {
            loadUserDict()
        }
    }
    
    // MARK: - 方法
    private func loadUserDict() {
        isLoading = true
        
        let rimeDir = rimeManager.rimeUserDir
        let userDictFile = rimeDir.appendingPathComponent("user.dict.yaml")
        
        DispatchQueue.global(qos: .userInitiated).async {
            var entries: [DictEntry] = []
            
            print("尝试加载用户词典: \(userDictFile.path)")
            
            if FileManager.default.fileExists(atPath: userDictFile.path) {
                do {
                    let content = try String(contentsOf: userDictFile, encoding: .utf8)
                    entries = parseUserDict(content)
                    print("成功加载了 \(entries.count) 个词汇")
                } catch {
                    print("加载失败: \(error)")
                }
            } else {
                // 检查其他词典文件
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: rimeDir.path)
                    let dictFiles = contents.filter { $0.hasSuffix(".dict.yaml") }
                    print("找到词典文件: \(dictFiles)")
                    
                    for dictFile in dictFiles {
                        let fullPath = rimeDir.appendingPathComponent(dictFile)
                        let content = try String(contentsOf: fullPath, encoding: .utf8)
                        let dictEntries = parseUserDict(content)
                        entries.append(contentsOf: dictEntries)
                        print("从 \(dictFile) 加载了 \(dictEntries.count) 个词汇")
                    }
                } catch {
                    print("扫描目录失败: \(error)")
                }
            }
            
            if entries.isEmpty {
                entries = [
                    DictEntry(word: "配置工具", code: "pzgj", weight: 100),
                    DictEntry(word: "输入法", code: "srf", weight: 90)
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
        var inDataSection = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            if trimmed == "..." {
                inDataSection = true
                continue
            }
            
            if trimmed.hasPrefix("---") ||
               trimmed.hasPrefix("name:") ||
               trimmed.hasPrefix("version:") ||
               trimmed.hasPrefix("sort:") ||
               trimmed.hasPrefix("use_preset_vocabulary:") {
                continue
            }
            
            if inDataSection {
                let parts = trimmed.components(separatedBy: CharacterSet.whitespacesAndNewlines).filter { !$0.isEmpty }
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
    
    private func saveUserDict() {
        let rimeDir = rimeManager.rimeUserDir
        let userDictFile = rimeDir.appendingPathComponent("user.dict.yaml")
        
        var yamlContent = """
# Rime 用户词典

---
name: user
version: "1.0"
sort: by_weight
use_preset_vocabulary: true
...

"""
        
        for entry in userDictEntries.sorted(by: { $0.weight > $1.weight }) {
            if entry.weight > 0 {
                yamlContent += "\(entry.word)\t\(entry.code)\t\(entry.weight)\n"
            } else {
                yamlContent += "\(entry.word)\t\(entry.code)\n"
            }
        }
        
        do {
            try yamlContent.write(to: userDictFile, atomically: true, encoding: .utf8)
            print("保存成功到: \(userDictFile.path)")
        } catch {
            print("保存失败: \(error)")
        }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let content = try String(contentsOf: url)
                let importedEntries = parseImportedDict(content)
                userDictEntries.append(contentsOf: importedEntries)
            } catch {
                print("导入失败: \(error)")
            }
        case .failure(let error):
            print("文件选择失败: \(error)")
        }
    }
    
    private func parseImportedDict(_ content: String) -> [DictEntry] {
        var entries: [DictEntry] = []
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
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
    
    private func exportDictionary() {
        let savePanel = NSSavePanel()
        savePanel.title = "导出用户词典"
        savePanel.nameFieldStringValue = "用户词典.txt"
        savePanel.allowedContentTypes = [UTType.plainText]
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                var content = "# 用户词典导出\n\n"
                for entry in userDictEntries {
                    content += "\(entry.word)\t\(entry.code)\t\(entry.weight)\n"
                }
                
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    print("导出成功")
                } catch {
                    print("导出失败: \(error)")
                }
            }
        }
    }
    
    private func deleteEntry(_ entry: DictEntry) {
        userDictEntries.removeAll { $0.id == entry.id }
    }
}

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
            
            Form {
                TextField("词汇", text: $word)
                TextField("编码", text: $code)
                TextField("权重", value: $weight, format: .number)
            }
            .frame(width: 300)
            
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
        .frame(width: 400, height: 300)
    }
}

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
            
            Form {
                TextField("词汇", text: $word)
                TextField("编码", text: $code)
                TextField("权重", value: $weight, format: .number)
            }
            .frame(width: 300)
            
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
        .frame(width: 400, height: 300)
    }
}
