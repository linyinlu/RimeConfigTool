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
