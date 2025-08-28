# RimeConfigTool
Provide visualized GUI for Rime IME in Mac

主要功能模块

主应用 (RimeConfigToolApp.swift) - SwiftUI 应用入口，提供现代化的侧边栏导航界面

核心管理器 (RimeManager.swift) - 负责：

- Rime 安装状态检测
- 配置文件读写（YAML格式）
- 输入方案管理
- 主题配置
- 自动部署功能


基本设置 (GeneralConfigView.swift) - 提供：

- Rime 状态监控
- 候选词和分页设置
- 快捷操作（部署、备份等）
- 目录访问功能


方案管理 (SchemaManagerView.swift) - 支持：

- 可视化启用/禁用输入方案
- 方案搜索和筛选
- 方案详情查看
- 添加自定义方案


主题编辑器 (ThemeEditorView.swift) - 包含：

- 实时主题预览
- 可视化颜色编辑
- 布局和样式设置
- 候选框效果预览


词库管理 (DictManagerView.swift) - 提供：

- 用户词典可视化管理
- 词汇增删改查
- 导入/导出功能
- 多格式支持

技术特点

- Swift + SwiftUI 开发，现代化界面
- 直接操作 Rime 配置文件，无需额外安装
- 实时预览功能，所见即所得
- 完整的错误处理和用户反馈
- 模块化设计，易于扩展维护

操作系统：macOS 26.0 Beta (25A5349a)
Chip: Apple M1 Max
Memory: 64G
Xcode: 16.4 (16F6)


2025-08-28 - 现存Bug，请勿直接编译安装，修复处理中：
1. 无法调用macOS调色板
2. 无法导出词典（引发程序退出）
3. Rime配置文件夹错误
