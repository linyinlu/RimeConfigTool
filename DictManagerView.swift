import SwiftUI
import UniformTypeIdentifiers

struct DictManagerView: View {
    @ObservedObject var rimeManager: RimeManager
    @State private var entries: [DictEntry] = []
    @State private var files: [URL] = []
    @State private var selectedFile: URL?
    @State private var search = ""
    @State private var showingAdd = false
    @State private var showingImport = false
    @State private var editing: DictEntry?
    @State private var newName = "custom"
    @State private var error: String?

    private var filtered: [DictEntry] {
        search.isEmpty ? entries : entries.filter { $0.word.localizedCaseInsensitiveContains(search) || $0.code.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack {
            HStack {
                Text("词库管理").font(.title2)
                Picker("词典", selection: $selectedFile) {
                    Text("选择词典").tag(URL?.none)
                    ForEach(files, id: \.self) { Text($0.lastPathComponent).tag(Optional($0)) }
                }.frame(maxWidth: 300)
                Button("刷新") { refresh() }
            }
            HStack {
                TextField("新词典名称（英文、数字、下划线）", text: $newName)
                Button("新建词典") { createDictionary() }
            }
            HStack {
                TextField("搜索词汇或编码", text: $search)
                Button("添加词汇") { showingAdd = true }.disabled(selectedFile == nil)
                Button("导入词条") { showingImport = true }.disabled(selectedFile == nil)
                Button("导出词典") { exportDictionary() }.disabled(selectedFile == nil)
            }
            List {
                ForEach(filtered) { entry in
                    HStack {
                        Text(entry.word).frame(maxWidth: .infinity, alignment: .leading)
                        Text(entry.code).frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(entry.weight)")
                        Button("编辑") { editing = entry }
                        Button("删除") { entries.removeAll { $0.id == entry.id } }
                    }
                }
            }
            HStack {
                Text("共 \(entries.count) 条 · 保存仅修改当前选中的词典")
                Spacer()
                Button("保存词典") { save() }.disabled(selectedFile == nil)
            }
        }
        .padding()
        .onAppear { refresh() }
        .onChange(of: selectedFile) { _ in load() }
        .sheet(isPresented: $showingAdd) { AddDictEntryView { entries.append($0) } }
        .sheet(item: $editing) { original in
            EditDictEntryView(entry: original) { updated in
                if let index = entries.firstIndex(where: { $0.id == original.id }) {
                    entries[index].word = updated.word
                    entries[index].code = updated.code
                    entries[index].weight = updated.weight
                }
            }
        }
        .fileImporter(isPresented: $showingImport, allowedContentTypes: [.plainText, .commaSeparatedText], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                entries.append(contentsOf: parse(try String(contentsOf: url, encoding: .utf8)))
            } catch { self.error = error.localizedDescription }
        }
        .alert("操作失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("确定") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func refresh() {
        do {
            files = try FileManager.default.contentsOfDirectory(at: rimeManager.rimeUserDir, includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.hasSuffix(".dict.yaml") }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            if !files.contains(where: { $0 == selectedFile }) { selectedFile = files.first }
            load()
        } catch {
            files = []; selectedFile = nil; entries = []
            if (error as NSError).code != NSFileReadNoSuchFileError { self.error = error.localizedDescription }
        }
    }

    private func load() {
        guard let url = selectedFile else { entries = []; return }
        do { entries = parse(try String(contentsOf: url, encoding: .utf8)) }
        catch { error = error.localizedDescription }
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
        guard !newName.isEmpty, newName.range(of: "^[a-zA-Z][a-zA-Z0-9_]*$", options: .regularExpression) != nil else {
            error = "词典名称须以英文字母开头，只含字母、数字和下划线"; return
        }
        let url = rimeManager.rimeUserDir.appendingPathComponent("\(newName).dict.yaml")
        guard !FileManager.default.fileExists(atPath: url.path) else { error = "同名词典已存在"; return }
        do {
            try FileManager.default.createDirectory(at: rimeManager.rimeUserDir, withIntermediateDirectories: true)
            try "---\nname: \(newName)\nversion: \"1.0\"\nsort: by_weight\n...\n".write(to: url, atomically: true, encoding: .utf8)
            refresh(); selectedFile = url
        } catch { error = error.localizedDescription }
    }

    private func save() {
        guard let url = selectedFile else { return }
        guard entries.allSatisfy({ !$0.word.isEmpty && !$0.code.isEmpty && !$0.word.contains(where: \.isWhitespace) && !$0.code.contains(where: \.isWhitespace) }) else {
            error = "词条和编码不能为空或含空白字符"; return
        }
        do {
            let old = try String(contentsOf: url, encoding: .utf8)
            guard let marker = old.range(of: "...", options: .anchored, range: old.startIndex..<old.endIndex) ?? old.range(of: "\n...\n") else {
                error = "词典缺少 YAML 正文分隔符 ..."; return
            }
            let header = String(old[..<marker.upperBound]).trimmingCharacters(in: .newlines)
            let body = entries.map { "\($0.word)\t\($0.code)\t\($0.weight)" }.joined(separator: "\n")
            let backup = url.appendingPathExtension("backup")
            if FileManager.default.fileExists(atPath: backup.path) { try FileManager.default.removeItem(at: backup) }
            try FileManager.default.copyItem(at: url, to: backup)
            try "\(header)\n\(body)\n".write(to: url, atomically: true, encoding: .utf8)
            rimeManager.deployRime()
        } catch { error = error.localizedDescription }
    }

    private func exportDictionary() {
        guard let url = selectedFile else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = url.lastPathComponent
        panel.allowedContentTypes = [.plainText]
        panel.begin { response in
            guard response == .OK, let destination = panel.url else { return }
            do { try Data(contentsOf: url).write(to: destination, options: .atomic) }
            catch { error = error.localizedDescription }
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
