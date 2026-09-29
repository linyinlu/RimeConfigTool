# RimeConfigTool

macOS 上的 Rime（鼠须管）可视化配置工具，管理输入方案、主题和 `.dict.yaml` 文本词典。

## 构建

需要 macOS、Xcode 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。在仓库目录执行：

```sh
brew install xcodegen
xcodegen generate
open RimeConfigTool.xcodeproj
```

在 Xcode 中选择 RimeConfigTool scheme 运行。仓库原有工程缺少 `project.pbxproj`，所以使用 `project.yml` 生成工程。应用不启用 App Sandbox，才能访问当前用户的 `~/Library/Rime`；不要将这一配置用于 Mac App Store 分发。

## 使用和限制

- 默认目录是当前用户的 `~/Library/Rime`，可在基本设置里选择已有的其他目录。
- 词库页只修改当前选中的文本 `.dict.yaml`，可以新建、导入词条、编辑、导出；保存前生成 `.backup`。Rime 自动学习的二进制用户词典不在本工具的编辑范围内。
- 输入方案从本地 `.schema.yaml` 发现；仅启用/停用已有方案。首次保存会创建 `default.custom.yaml`，主题会创建 `squirrel.custom.yaml`。已有的手写 custom 文件会拒绝覆盖，以免丢失其他设置。工具管理的文件在再次保存前备份为 `.backup`。
- 保存后尝试调用 Squirrel `--reload`；若本机版本不支持，请在鼠须管菜单中手动重新部署。使用前请备份整个 Rime 配置目录。

目前没有在 macOS/Xcode 环境中完成编译和实际鼠须管部署验证。

## 文本词库迁移与备份（开发中）

可以从搜狗、百度等输入法导出可读取的文本文件后，在词库页预览导入。当前识别 UTF-8、UTF-16、GB18030 的 `词语<TAB>编码<TAB>权重`、空格或逗号分列格式；不读取 `.scel` 等私有二进制词库，也不自动为词语生成拼音编码。预览会报告跳过行，导入后还需保存。新建词典文件后须将其接入对应 Rime 方案，才会出现在输入候选中。

基本设置可将顶层 YAML、TXT、LUA 文件备份到用户选择的文件夹。选择云盘的本机同步目录即可由云盘客户端负责同步；此功能不登录云盘账号、不做自动定时备份，也不包含 Rime 自动学习的二进制数据。还原需手动核对后复制文件。

后续工作：方案级简繁与英文默认模式、快捷键可视化编辑、词典与具体方案的安全关联、备份恢复与冲突处理、原输入法私有格式转换适配。每项需在实际方案和导出样本上验证后再启用。
