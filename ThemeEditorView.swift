import SwiftUI

struct ThemeEditorView: View {
    @ObservedObject var rimeManager: RimeManager
    @State private var editingTheme: RimeTheme
    @State private var showingPreview = true

    private var hasInvalidColor: Bool {
        [editingTheme.backgroundColor, editingTheme.borderColor, editingTheme.textColor,
         editingTheme.highlightedColor, editingTheme.candidateTextColor]
            .contains { SquirrelColor.parse($0) == nil }
    }
    
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
                                if hasInvalidColor {
                                    Text("请修正颜色值后再应用主题；鼠须管使用 0xBBGGRR 或 0xAABBGGRR。")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
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
                    .disabled(hasInvalidColor)
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
            .accessibilityLabel("\(label)色样")
            
            TextField("颜色值", text: $colorHex)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .accessibilityLabel("\(label)色值")
                .help("鼠须管颜色格式：0xBBGGRR 或 0xAABBGGRR")
        }
        .onAppear {
            selectedColor = Color(hex: colorHex) ?? .white
        }
        .onChange(of: colorHex) { newValue in
            if let color = Color(hex: newValue) {
                selectedColor = color
            }
        }
        .onChange(of: selectedColor) { newColor in
            colorHex = newColor.toHexString()
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerSheet(
                selectedColor: $selectedColor,
                title: label
            )
        }
    }
}

struct ColorPickerSheet: View {
    @Binding var selectedColor: Color
    let title: String
    @State private var draftColor: Color = .white
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("选择\(title)")
                .font(.title2)
                .fontWeight(.semibold)
            
            ColorPicker("", selection: $draftColor, supportsOpacity: false)
                .labelsHidden()
                .scaleEffect(1.5)
                .frame(width: 200, height: 100)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("颜色预览")
                    .font(.headline)
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(draftColor)
                    .frame(height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                
                Text("鼠须管色值：\(draftColor.toHexString())")
                    .font(.system(.body, design: .monospaced))
            }
            .frame(width: 250)
            
            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("确定") {
                    selectedColor = draftColor
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 300, height: 400)
        .onAppear { draftColor = selectedColor }
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

// 鼠须管颜色值以 BGR 顺序存储，预览与取色器使用 RGB。
extension Color {
    init?(hex: String) {
        guard let color = SquirrelColor.parse(hex) else { return nil }
        self.init(
            .sRGB,
            red: Double(color.red) / 255,
            green: Double(color.green) / 255,
            blue: Double(color.blue) / 255,
            opacity: Double(color.alpha) / 255
        )
    }

    func toHexString() -> String {
        guard let rgb = NSColor(self).usingColorSpace(.deviceRGB) else { return "0x000000" }
        func byte(_ component: CGFloat) -> UInt8 {
            UInt8(max(0, min(255, Int((component * 255).rounded()))))
        }
        return SquirrelColor(
            red: byte(rgb.redComponent),
            green: byte(rgb.greenComponent),
            blue: byte(rgb.blueComponent),
            alpha: byte(rgb.alphaComponent)
        ).encoded
    }
}

#Preview {
    ThemeEditorView(rimeManager: RimeManager())
        .frame(width: 900, height: 700)
}
