import SwiftUI

struct SchemaSwitchSetting: Identifiable {
    let index: Int
    let name: String
    let states: [String]
    var id: Int { index }
}

struct SchemaSwitchView: View {
    @ObservedObject var rimeManager: RimeManager
    let schema: RimeSchema
    @Environment(\.dismiss) private var dismiss
    @State private var switches: [SchemaSwitchSetting] = []
    @State private var selected: [Int: Int] = [:]
    @State private var loadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\\(schema.name) · 默认输入状态").font(.title2)
            Text("只设置切换到该输入方案时的初始状态；运行中的简繁和中英文切换仍在鼠须管输入法菜单进行。")
                .foregroundColor(.secondary)
            if switches.isEmpty { Text(loadError ?? "该方案没有可识别的状态开关") }
            Form {
                ForEach(switches) { item in
                    Picker(item.name, selection: Binding(
                        get: { selected[item.index] ?? 0 },
                        set: { selected[item.index] = $0 }
                    )) {
                        ForEach(Array(item.states.enumerated()), id: \.offset) { index, state in
                            Text(state).tag(index)
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存并部署") {
                    rimeManager.saveSchemaSwitches(schemaId: schema.schemaId, selections: selected)
                    if rimeManager.errorMessage == nil { dismiss() }
                }.buttonStyle(.borderedProminent).disabled(switches.isEmpty)
            }
        }.padding().frame(width: 520, height: 440)
            .onAppear {
                do {
                    switches = try rimeManager.schemaSwitches(for: schema.schemaId)
                    selected = Dictionary(uniqueKeysWithValues: switches.map { ($0.index, 0) })
                } catch { loadError = error.localizedDescription }
            }
    }
}
