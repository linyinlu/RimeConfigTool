import SwiftUI
import UniformTypeIdentifiers

// 编辑会话由 ContentView 持有，切换侧边栏页面时仍保留未保存的词条。
@MainActor
final class DictionaryDraft: ObservableObject {
    @Published var entries: [DictEntry] = []
    @Published var files: [URL] = []
    @Published var selectedFile: URL?
    @Published var isDirty = false
    var loadedDirectory: URL?
    var loadedContent: String?
}

struct DictManagerView: View {
    @ObservedObject var rimeManager: RimeManager
    @ObservedObject var draft: DictionaryDraft
    @State private var search = ""
    @State private var showingAdd = false
    @State private var showingImport = false
    @State private var editing: DictEntry?
    @State private var newName = "custom"
    @State private var errorText: String?
    @State private var notice: String?
    @State private var pendingImport: DictionaryImportResult?
    @State private var showingImportPreview = false
    @State private var pendingAction: PendingAction?
    @State private var showingUnsavedAlert = false

    private enum PendingAction {
        case select(URL?)
        case refresh
    }

    private var filtered: [DictEntry] {
        search.isEmpty ? draft.entries : draft.entries.filter { $0.word.localizedCaseInsensitiveContains(search) || $0.code.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack {
            HStack {
                Text("词库管理").font(.title2)
                Picker("词典", selection: Binding(
                    get: { draft.selectedFile },
                    set: { request(.select($0)) }
                )) {
                    Text("选择词典").tag(URL?.none)
                    ForEach(draft.files, id: \.self) { Text($0.lastPathComponent).tag(Optional($0)) }
                }.frame(maxWidth: 300)
                Button("刷新") { request(.refresh) }
            }
            HStack {
                TextField("新词典名称（英文、数字、下划线）", text: $newName)
                Button("新建词典") { createDictionary() }
                    .disabled(draft.isDirty)
                    .help(draft.isDirty ? "请先保存或放弃当前词典的修改" : "创建空白 Rime 文本词典")
            }
            HStack {
                TextField("搜索词汇或编码", text: $search)
                Button("添加词汇") { showingAdd = true }.disabled(draft.selectedFile == nil)
                Button("导入文本词库") { showingImport = true }.disabled(draft.selectedFile == nil)
                Button(draft.isDirty ? "导出未保存词条" : "导出词典") { exportDictionary() }
                    .disabled(draft.selectedFile == nil)
            }
            List {
                ForEach(filtered) { entry in
                    HStack {
                        Text(entry.word).frame(maxWidth: .infinity, alignment: .leading)
                        Text(entry.code).frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(entry.weight)")
                        Button("编辑") { editing = entry }
                        Button("删除") {
                            draft.entries.removeAll { $0.id == entry.id }
                            draft.isDirty = true
                        }
                    }
                }
            }
            if let notice { Text(notice).font(.caption).foregroundColor(.secondary) }
            HStack {
                Text("共 \(draft.entries.count) 条\(draft.isDirty ? " · 有未保存修改" : "") · 保存仅修改当前选中的词典")
                Spacer()
                Button("保存词典") { _ = save() }.disabled(draft.selectedFile == nil || !draft.isDirty)
            }
        }
        .padding()
        .onAppear {
            if draft.loadedDirectory == nil { refresh() }
            else if draft.loadedDirectory != rimeManager.rimeUserDir { request(.refresh) }
        }
        .sheet(isPresented: $showingAdd) { AddDictEntryView {
            draft.entries.append($0)
            draft.isDirty = true
        } }
        .sheet(item: $editing) { original in
            EditDictEntryView(entry: original) { updated in
                if let index = draft.entries.firstIndex(where: { $0.id == original.id }) {
                    if draft.entries[index].word != updated.word || draft.entries[index].code != updated.code || draft.entries[index].weight != updated.weight {
                        draft.entries[index].word = updated.word
                        draft.entries[index].code = updated.code
                        draft.entries[index].weight = updated.weight
                        draft.isDirty = true
                    }
                }
            }
        }
        .fileImporter(isPresented: $showingImport, allowedContentTypes: [.plainText, .commaSeparatedText], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                pendingImport = try DictionaryImport.read(Data(contentsOf: url))
                showingImportPreview = true
            } catch { self.errorText = error.localizedDescription }
        }
        .sheet(isPresented: $showingImportPreview) {
            VStack(alignment: .leading, spacing: 12) {
                Text("确认导入词条").font(.title2)
                Text("格式：\(pendingImport?.format ?? "")；可导入 \(pendingImport?.entries.count ?? 0) 条，跳过 \(pendingImport?.skipped ?? 0) 行。")
                Text("预览前 10 条；相同词语与编码将保留现有词条。导入后仍需点击保存词典。")
                    .foregroundColor(.secondary)
                List(Array((pendingImport?.entries ?? []).prefix(10))) { entry in
                    HStack { Text(entry.word); Spacer(); Text(entry.code); Text("\(entry.weight)") }
                }
                HStack {
                    Spacer()
                    Button("取消") { showingImportPreview = false; pendingImport = nil }
                    Button("导入到当前词典") {
                        let existing = Set(draft.entries.map { "\($0.word)\t\($0.code)" })
                        var seen = existing
                        for entry in pendingImport?.entries ?? [] {
                            if seen.insert("\(entry.word)\t\(entry.code)").inserted {
                                draft.entries.append(entry)
                                draft.isDirty = true
                            }
                        }
                        showingImportPreview = false; pendingImport = nil
                    }.buttonStyle(.borderedProminent)
                }
            }.padding().frame(width: 600, height: 420)
        }
        .alert("操作失败", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("确定") { errorText = nil }
        } message: { Text(errorText ?? "") }
        .alert("当前词典有未保存的修改", isPresented: $showingUnsavedAlert) {
            Button("保存后继续") {
                if save() { completePendingAction() }
                else { pendingAction = nil }
            }
            Button("放弃修改", role: .destructive) { completePendingAction() }
            Button("取消", role: .cancel) { pendingAction = nil }
        } message: {
            Text("切换词典或刷新会重新读取文件，未保存的词条将丢失。")
        }
    }

    private func request(_ action: PendingAction) {
        if draft.isDirty {
            pendingAction = action
            showingUnsavedAlert = true
        } else {
            perform(action)
        }
    }

    private func completePendingAction() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        perform(action)
    }

    private func perform(_ action: PendingAction) {
        switch action {
        case .select(let url):
            guard url != draft.selectedFile else { return }
            load(url)
        case .refresh:
            refresh()
        }
    }

    private func refresh() {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: rimeManager.rimeUserDir, includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.hasSuffix(".dict.yaml") }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            let selected = files.contains(where: { $0 == draft.selectedFile }) ? draft.selectedFile : files.first
            load(selected)
            draft.files = files
            draft.loadedDirectory = rimeManager.rimeUserDir
        } catch {
            if (error as NSError).code != NSFileReadNoSuchFileError { self.errorText = error.localizedDescription }
        }
    }

    private func load(_ url: URL?) {
        guard let url else {
            draft.selectedFile = nil; draft.entries = []; draft.loadedContent = nil; draft.isDirty = false
            return
        }
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            draft.entries = parse(content)
            draft.selectedFile = url
            draft.loadedContent = content
            draft.isDirty = false
        }
        catch { errorText = error.localizedDescription }
    }

    private func parse(_ content: String) -> [DictEntry] {
        var inBody = false
        var result: [DictEntry] = []
        for line in content.components(separatedBy: .newlines) {
            let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if text == "..." { inBody = true; continue }
            if text.isEmpty || text.hasPrefix("#") || text == "---" { continue }
            if !inBody && text.contains(":") { continue }
            let parts = text.split(whereSeparator: { $0 == "\t" || $0 == " " }).map(String.init)
            if parts.count >= 2 { result.append(DictEntry(word: parts[0], code: parts[1], weight: parts.count > 2 ? Int(parts[2]) ?? 0 : 0)) }
        }
        return result
    }

    private func createDictionary() {
        guard !draft.isDirty else { errorText = "请先保存或放弃当前词典的修改"; return }
        guard !newName.isEmpty, newName.range(of: "^[a-zA-Z][a-zA-Z0-9_]*$", options: .regularExpression) != nil else {
            errorText = "词典名称须以英文字母开头，只含字母、数字和下划线"; return
        }
        let url = rimeManager.rimeUserDir.appendingPathComponent("\(newName).dict.yaml")
        guard !FileManager.default.fileExists(atPath: url.path) else { errorText = "同名词典已存在"; return }
        do {
            try FileManager.default.createDirectory(at: rimeManager.rimeUserDir, withIntermediateDirectories: true)
            try "---\nname: \(newName)\nversion: \"1.0\"\nsort: by_weight\n...\n".write(to: url, atomically: true, encoding: .utf8)
            refresh(); load(url)
            notice = "词典已创建。还需在对应方案配置 import_tables 或 translator/packs，才能进入候选。"
        } catch { errorText = error.localizedDescription }
    }

    @discardableResult
    private func save() -> Bool {
        guard let url = draft.selectedFile else { return false }
        guard draft.entries.allSatisfy({ !$0.word.isEmpty && !$0.code.isEmpty && !$0.word.contains(where: \.isWhitespace) && !$0.code.contains(where: \.isWhitespace) }) else {
            errorText = "词条和编码不能为空或含空白字符"; return false
        }
        do {
            let old = try String(contentsOf: url, encoding: .utf8)
            guard old == draft.loadedContent else {
                errorText = "词典已被其他程序修改。请先导出未保存词条，再刷新词典。"
                return false
            }
            guard let marker = old.range(of: "...", options: .anchored, range: old.startIndex..<old.endIndex) ?? old.range(of: "\n...\n") else {
                errorText = "词典缺少 YAML 正文分隔符 ..."; return false
            }
            let header = String(old[..<marker.upperBound]).trimmingCharacters(in: .newlines)
            let originalBody = String(old[marker.upperBound...])
            let bodyLines = originalBody.components(separatedBy: .newlines)
            let comments = bodyLines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
            // 无法解析的正文行不应被静默删除。
            let unknown = bodyLines.filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty || trimmed.hasPrefix("#") { return false }
                return trimmed.split(whereSeparator: \.isWhitespace).count < 2
            }
            guard unknown.isEmpty else { errorText = "词典包含无法解析的正文行，已停止保存以避免丢失数据"; return false }
            let body = (comments + draft.entries.map { "\($0.word)\t\($0.code)\t\($0.weight)" }).joined(separator: "\n")
            let backup = url.appendingPathExtension("backup")
            if FileManager.default.fileExists(atPath: backup.path) { try FileManager.default.removeItem(at: backup) }
            try FileManager.default.copyItem(at: url, to: backup)
            let updated = "\(header)\n\(body)\n"
            try updated.write(to: url, atomically: true, encoding: .utf8)
            draft.loadedContent = updated
            draft.isDirty = false
            notice = "词典已保存"
            rimeManager.deployRime()
            return true
        } catch { errorText = error.localizedDescription; return false }
    }

    private func exportDictionary() {
        guard let url = draft.selectedFile else { return }
        let hasUnsavedChanges = draft.isDirty
        let currentEntries = draft.entries
        let panel = NSSavePanel()
        panel.nameFieldStringValue = hasUnsavedChanges ? "\(url.deletingPathExtension().lastPathComponent)-未保存词条.json" : url.lastPathComponent
        panel.allowedContentTypes = hasUnsavedChanges ? [.json] : [.plainText]
        panel.begin { response in
            guard response == .OK, let destination = panel.url else { return }
            do {
                if hasUnsavedChanges {
                    let rows: [[String: Any]] = currentEntries.map { ["word": $0.word, "code": $0.code, "weight": $0.weight] }
                    let data = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
                    try data.write(to: destination, options: .atomic)
                } else {
                    try Data(contentsOf: url).write(to: destination, options: .atomic)
                }
            }
            catch { errorText = error.localizedDescription }
        }
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
