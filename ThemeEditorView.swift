import SwiftUI

struct ThemeEditorView: View {
    @ObservedObject var rimeManager: RimeManager
    @State private var editingTheme: RimeTheme
    @State private var showingPreview = true
    
    init(rimeManager: RimeManager) {
        self.rimeManager = rimeManager
        self._editingTheme = State(initialValue: rimeManager.currentTheme)
    }
    
    var body: some View {
        HSplitView {
            // 左侧编辑面板
            VStack(spacing: 0) {
                // 标题
                HStack {
                    Text("主题编辑器")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("重置") {
                        editingTheme = RimeTheme.default
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                
                Divider()
                
                // 编辑表单
                ScrollView {
                    VStack(spacing: 20) {
                        // 基本设置
                        GroupBox("基本设置") {
                            VStack(spacing: 12) {
                                HStack {
                                    Text("主题名称")
                                        .frame(width: 100, alignment: .leading)
                                    TextField("主题名称", text: $editingTheme.name)
                                }
                                
                                HStack {
                                    Text("水平排列")
                                        .frame(width: 100, alignment: .leading)
                                    Toggle("", isOn: $editingTheme.horizontal)
                                    Spacer()
                                }
                                
                                HStack {
                                    Text("内嵌预编辑")
                                        .frame(width: 100, alignment: .leading)
                                    Toggle("", isOn: $editingTheme.inlinePreedit)
                                    Spacer()
                                }
                            }
                            .padding()
                        }
                        
                        // 外观设置
                        GroupBox("外观设置") {
                            VStack(spacing: 12) {
                                HStack {
                                    Text("圆角半径")
                                        .frame(width: 100, alignment: .leading)
                                    Slider(value: $editingTheme.cornerRadius, in: 0...20, step: 0.5)
                                    Text("\(editingTheme.cornerRadius, specifier: "%.1f")")
                                        .frame(width: 40, alignment: .trailing)
                                }
                                
                                HStack {
                                    Text("边框高度")
                                        .frame(width: 100, alignment: .leading)
                                    Slider(value: $editingTheme.borderHeight, in: 0...10, step: 0.5)
                                    Text("\(editingTheme.borderHeight, specifier: "%.1f")")
                                        .frame(width: 40, alignment: .trailing)
                                }
                                
                                HStack {
                                    Text("边框宽度")
                                        .frame(width: 100, alignment: .leading)
                                    Slider(value: $editingTheme.borderWidth, in: 0...5, step: 0.5)
                                    Text("\(editingTheme.borderWidth, specifier: "%.1f")")
                                        .frame(width: 40, alignment: .trailing)
                                }
                            }
                            .padding()
                        }
                        
                        // 颜色设置
                        GroupBox("颜色设置") {
                            VStack(spacing: 12) {
                                ColorPickerRow(label: "背景颜色", colorHex: $editingTheme.backgroundColor)
                                ColorPickerRow(label: "边框颜色", colorHex: $editingTheme.borderColor)
                                ColorPickerRow(label: "文字颜色", colorHex: $editingTheme.textColor)
                                ColorPickerRow(label: "高亮颜色", colorHex: $editingTheme.highlightedColor)
                                ColorPickerRow(label: "候选词颜色", colorHex: $editingTheme.candidateTextColor)
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                // 底部按钮
                HStack {
                    Button("恢复默认") {
                        editingTheme = rimeManager.currentTheme
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("应用主题") {
                        rimeManager.saveTheme(editingTheme)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .frame(minWidth: 350)
            
            // 右侧预览面板
            VStack(spacing: 0) {
                HStack {
                    Text("实时预览")
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Toggle("显示预览", isOn: $showingPreview)
                }
                .padding()
                
                Divider()
                
                if showingPreview {
                    ThemePreviewView(theme: editingTheme)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("预览已隐藏")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 400)
        }
        .onAppear {
            editingTheme = rimeManager.currentTheme
        }
    }
}

struct ColorPickerRow: View {
    let label: String
    @Binding var colorHex: String
    @State private var selectedColor: Color = .white
    @State private var showingColorPicker = false
    
    var body: some View {
        HStack {
            Text(label)
                .frame(width: 100, alignment: .leading)
            
            Button(action: {
                showingColorPicker = true
            }) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: colorHex) ?? .gray)
                    .frame(width: 40, height: 25)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("点击选择颜色")
            
            TextField("颜色值", text: $colorHex)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
        }
        .onAppear {
            selectedColor = Color(hex: colorHex) ?? .white
        }
        .onChange(of: colorHex) { newValue in
            selectedColor = Color(hex: newValue) ?? .white
        }
        .onChange(of: selectedColor) { newColor in
            colorHex = newColor.toHexString()
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerSheet(
                selectedColor: $selectedColor,
                colorHex: $colorHex,
                title: label
            )
        }
    }
}

struct ColorPickerSheet: View {
    @Binding var selectedColor: Color
    @Binding var colorHex: String
    let title: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("选择\(title)")
                .font(.title2)
                .fontWeight(.semibold)
            
            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .scaleEffect(1.5)
                .frame(width: 200, height: 100)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("颜色预览")
                    .font(.headline)
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedColor)
                    .frame(height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                
                HStack {
                    Text("十六进制值:")
                    TextField("颜色值", text: $colorHex)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .frame(width: 250)
            
            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("确定") {
                    colorHex = selectedColor.toHexString()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 300, height: 400)
    }
}

struct ThemePreviewView: View {
    let theme: RimeTheme
    
    var body: some View {
        VStack(spacing: 30) {
            Text("输入法预览")
                .font(.title2)
                .foregroundColor(.secondary)
            
            // 模拟候选词窗口
            VStack(spacing: 0) {
                // 候选词
                let candidates = ["中国", "中过", "忠国", "中锅", "中果"]
                
                if theme.horizontal {
                    // 水平排列
                    HStack(spacing: 0) {
                        ForEach(Array(candidates.enumerated()), id: \.offset) { index, candidate in
                            HStack(spacing: 4) {
                                Text("\(index + 1)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                
                                Text(candidate)
                                    .font(.system(size: 14))
                                    .foregroundColor(index == 0 ?
                                        (Color(hex: theme.highlightedColor) ?? .orange) :
                                        (Color(hex: theme.candidateTextColor) ?? .black)
                                    )
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                index == 0 ?
                                    Color(hex: theme.highlightedColor)?.opacity(0.1) :
                                    Color.clear
                            )
                            .cornerRadius(3)
                            
                            if index < candidates.count - 1 {
                                Divider()
                                    .frame(height: 20)
                            }
                        }
                        Spacer()
                    }
                } else {
                    // 垂直排列
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(candidates.enumerated()), id: \.offset) { index, candidate in
                            HStack(spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, alignment: .leading)
                                
                                Text(candidate)
                                    .font(.system(size: 14))
                                    .foregroundColor(index == 0 ?
                                        (Color(hex: theme.highlightedColor) ?? .orange) :
                                        (Color(hex: theme.candidateTextColor) ?? .black)
                                    )
                                
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                index == 0 ?
                                    Color(hex: theme.highlightedColor)?.opacity(0.1) :
                                    Color.clear
                            )
                            .cornerRadius(3)
                        }
                    }
                }
            }
            .padding(8)
            .background(Color(hex: theme.backgroundColor) ?? .white)
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(Color(hex: theme.borderColor) ?? .gray,
                           lineWidth: theme.borderWidth)
            )
            .cornerRadius(theme.cornerRadius)
            .shadow(radius: 4, y: 2)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// 颜色扩展
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHexString() -> String {
        let components = self.cgColor?.components
        let r: CGFloat = components?[0] ?? 0.0
        let g: CGFloat = components?[1] ?? 0.0
        let b: CGFloat = components?[2] ?? 0.0
        
        let hexString = String(format: "0x%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        return hexString
    }
}

#Preview {
    ThemeEditorView(rimeManager: RimeManager())
        .frame(width: 900, height: 700)
}
