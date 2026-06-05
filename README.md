# CloudDisk

CloudDisk 是一个基于 SwiftUI 的简易个人网盘 iOS 客户端，面向课程项目实现。项目重点覆盖声明式 UI、本地 SQLite 存储、模拟网络数据解析、文件夹层级浏览、txt 阅读器、系统视频播放器、文件管理和 DeepLink 分享。

## 已实现功能

### 首页

- 展示个人信息与容量进度。
- 展示最近转存列表。
- 展示最近浏览列表。
- 首页支持上下滚动。
- 打开 txt 或视频文件后，会更新最近浏览时间。

### 文件列表

- 展示根目录文件。
- 支持文件类型：文件夹、txt、视频、其他。
- 支持文件夹点击进入。
- 支持返回上一级目录。
- 文件数据来自 `mock_files.json`，流程为 `JSON -> SQLite -> Model -> UI`。

### 文件打开

- 点击 `.txt` 文件进入文本阅读器。
- 点击视频文件进入系统播放器页面。
- 打开文件后写入 `last_opened_at`，用于最近浏览排序。

### txt 阅读器

- 支持文本分页。
- 左滑进入下一页。
- 右滑返回上一页。
- 底部显示当前页码和总页数。
- 第一页、最后一页会禁用对应翻页按钮。

### 文件管理

在文件列表中长按文件或文件夹，可打开操作菜单：

- 上传
- 重命名
- 移动
- 删除
- 分享链接

移动文件时可以选择根目录或其他文件夹。移动文件夹时会阻止移动到自身或子文件夹。

### 分享与 DeepLink

- 分享时生成本地 `shareId`。
- 分享链接格式：`clouddisk://share?id=share_xxx`
- 链接不包含文件名、路径等明文信息。
- App 收到 DeepLink 后，会根据 `shareId` 查询本地数据库并展示分享文件页。
- 当前实现为本机本地分享记录，不做跨设备转存。

## 技术结构

```text
CloudDisk/
  Models/          数据模型
  Views/           SwiftUI 页面
  ViewModels/      页面状态与交互逻辑
  Repositories/    数据仓库
  Services/        SQLite、mock 网络、文本内容读取
  Resources/       mock JSON 与 txt 示例内容
```

核心技术：

- SwiftUI
- SQLite3
- async/await
- NavigationStack
- AVPlayerViewController
- URL Scheme DeepLink

## 数据库字段

`files` 表：

```text
file_id
name
size
path
type
parent_id
timestamp
last_opened_at
saved_at
```

`share_records` 表：

```text
share_id
file_id
created_at
```

## 运行方式

1. 用 Xcode 打开 `CloudDisk.xcodeproj`。
2. 选择 Scheme：`CloudDisk`。
3. 选择 iPhone 模拟器，例如 `iPhone 17 Pro`。
4. 按 `Cmd + R` 运行。

如果模拟器安装失败，可以先执行：

1. `Shift + Cmd + K` 清理构建。
2. 在模拟器中删除旧的 `CloudDisk` App。
3. 再次按 `Cmd + R` 运行。

## 功能验收路径

完整测试清单见 [docs/QA_CHECKLIST.md](docs/QA_CHECKLIST.md)。交付说明见 [docs/DELIVERY_REPORT.md](docs/DELIVERY_REPORT.md)。项目总结见 [docs/PROJECT_SUMMARY.md](docs/PROJECT_SUMMARY.md)。

### 文件夹浏览

1. 打开 App。
2. 进入底部 `文件` Tab。
3. 点击 `学习资料`。
4. 应看到 `SwiftUI 笔记.txt`、`SQLite 设计.txt`、`归档`。
5. 点击 `返回上一级` 回到根目录。

### txt 阅读器

1. 进入 `文件` Tab。
2. 点击 `项目说明.txt`。
3. 进入阅读器后左滑，页码增加。
4. 右滑，页码减少。
5. 点击底部上一页/下一页按钮也可以翻页。

### 最近浏览

1. 打开任意 txt 文件。
2. 返回首页 `网盘` Tab。
3. 查看 `最近浏览`，刚打开的文件应出现在列表靠前位置。

### 文件管理

1. 进入 `文件` Tab。
2. 长按任意文件。
3. 选择 `重命名`，输入新名字并保存。
4. 长按文件，选择 `移动`，选择目标文件夹。
5. 长按文件，选择 `删除`，确认后文件从列表消失。

### 分享链接

1. 进入 `文件` Tab。
2. 长按任意文件或文件夹。
3. 选择 `分享链接`。
4. App 会生成并复制 `clouddisk://share?id=...` 链接。
5. 可在系统分享面板中分享，也可复制链接。

### DeepLink

1. 先通过文件菜单生成分享链接。
2. 在模拟器 Safari 地址栏输入生成的链接，例如：

```text
clouddisk://share?id=share_xxx
```

3. App 被拉起后，会展示分享文件页。

## 当前边界

- 上传文件会复制到 App 沙盒 `Documents/CloudDiskFiles`，并写入 SQLite。
- 视频播放器入口已接入系统播放器；内置 `video_demo.mp4` 或上传真实 mp4 后可以播放。
- 分享记录保存在本地数据库，不支持跨设备访问。
- 未接入广告 SDK、服务端、自定义播放器、KMP。

## 建议后续阶段

- 增加文件操作的单元测试。
- 优化 txt 阅读器为更精确的排版分页。
