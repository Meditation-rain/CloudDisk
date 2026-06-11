# CloudDisk

一个使用 SwiftUI 构建的 iOS 网盘示例应用，实现了文件浏览、文本阅读、视频播放、文件管理和 DeepLink 分享等核心功能。

---

## 功能概览

- **首页**：展示个人信息、存储容量进度条、最近转存和最近浏览
- **文件浏览**：支持多级目录导航，支持进入文件夹和返回上一级
- **文件管理**：支持上传、重命名、移动、删除和分享链接操作
- **文本阅读器**：支持文本分页、左右滑动翻页和页码显示
- **视频播放**：基于 `AVPlayerViewController` 的系统播放器
- **分享链接**：生成 `clouddisk://share?id=xxx` 格式的 DeepLink，可通过链接直接打开分享文件
- **本地数据库**：使用原生 SQLite3 API 持久化文件数据，无需第三方 ORM

---

## 技术栈

| 层次 | 技术 |
|------|------|
| UI 框架 | SwiftUI |
| 架构模式 | MVVM（ViewModel + Repository） |
| 数据库 | SQLite3（原生 C API） |
| 视频播放 | AVKit / AVPlayerViewController |
| 路由 | URL Scheme（`clouddisk://`） |
| 并发 | Swift Concurrency（async/await） |
| Mock 数据 | Bundle 内置 `mock_files.json` |

---

## 运行环境要求

| 环境 | 要求 |
|------|------|
| **Xcode** | 15.0 或更高版本 |
| **Swift** | 5.x（工程配置为 Swift 5.0） |
| **iOS 部署目标** | iOS 17.0 或更高版本 |
| **macOS（开发机）** | 建议 macOS Ventura 13.0 或更高版本 |
| **第三方依赖** | 无（不依赖 CocoaPods、Carthage 或 Swift Package） |

> 项目当前最低部署目标为 iOS 17.0，建议使用 iOS 17 及以上模拟器或真机调试。

---

## 项目结构

```text
CloudDisk/
├── CloudDiskApp.swift               # App 入口，注入 Repository 和 AppRouter
├── AppRouter.swift                  # DeepLink 路由状态（URL Scheme 解析）
├── ContentView.swift                # 根视图，搭建 TabView 和分享 Sheet
├── Info.plist                       # App 配置与 URL Scheme 声明
│
├── Models/
│   ├── FileItem.swift               # 文件 / 文件夹数据模型
│   ├── ShareRecord.swift            # 分享记录模型
│   └── DatabaseStats.swift          # 数据库统计信息模型
│
├── Repositories/
│   └── FileRepository.swift         # 业务聚合层，组合数据库和文件系统操作
│
├── Services/
│   ├── DatabaseService.swift        # SQLite3 数据访问层
│   ├── MockNetworkService.swift     # 模拟网络请求，从 Bundle 加载初始数据
│   └── TextContentService.swift     # txt 内容读取（Bundle + 沙盒路径）
│
├── ViewModels/
│   ├── FileBrowserViewModel.swift   # 文件浏览页状态与业务逻辑
│   └── HomeViewModel.swift          # 首页状态与数据加载
│
├── Views/
│   ├── HomeView.swift               # 首页
│   ├── FileBrowserView.swift        # 文件浏览页
│   ├── FileRowView.swift            # 文件列表行组件
│   ├── TextReaderView.swift         # txt 阅读器
│   ├── SystemVideoPlayerView.swift  # 视频播放器
│   └── ShareLandingView.swift       # DeepLink 分享落地页
│
└── Resources/
    ├── mock_files.json              # 初始化 mock 文件数据
    ├── txt_readme.txt               # 内置示例文本（项目说明）
    ├── txt_database.txt             # 内置示例文本（数据库介绍）
    ├── txt_swift.txt                # 内置示例文本（Swift 介绍）
    └── video_demo.mp4               # 内置示例视频
```

---

## 环境搭建指南

### 1. 安装 Xcode

前往 [Mac App Store](https://apps.apple.com/cn/app/xcode/id497799835) 或 [Apple Developer 下载页](https://developer.apple.com/download/applications/) 下载并安装 Xcode 15 或更高版本。

安装完成后，可在终端确认版本：

```bash
xcode-select --version
xcodebuild -version
```

### 2. 获取项目代码

如果你已经拿到代码，进入项目目录即可：

```bash
cd /Users/chenshiyu/code/SwiftProjects/CloudDisk
```

如果是从远程仓库获取，可先克隆后进入目录：

```bash
git clone <仓库地址>
cd CloudDisk
```

### 3. 打开工程

本项目使用 `.xcodeproj` 工程管理，直接打开下面这个文件即可：

```text
CloudDisk.xcodeproj
```

也可以在终端中执行：

```bash
open CloudDisk.xcodeproj
```

### 4. 检查签名配置

如果需要真机运行，建议先检查 Xcode 中的签名配置：

1. 打开工程后选中 `CloudDisk` Target。
2. 进入 `Signing & Capabilities`。
3. 选择你本机可用的 `Team`。
4. 如有需要，将 `Bundle Identifier` 修改为你自己的唯一值。

说明：

- 仅在模拟器运行时，一般不需要额外处理签名问题。
- 如果构建时报签名错误，优先检查 `Team` 和 `Bundle Identifier` 是否匹配本地环境。

### 5. 准备模拟器

建议在 Xcode 中准备一个 iOS 17 及以上模拟器，例如：

- iPhone 15
- iPhone 15 Pro
- iPhone 16 / 16 Pro

---

## 项目启动说明

### 方式一：使用 Xcode 图形界面（推荐）

1. 用 Xcode 打开 `CloudDisk.xcodeproj`。
2. 在顶部选择 Scheme：`CloudDisk`。
3. 选择一个 iOS 17.0 及以上的模拟器或已签名真机。
4. 点击左上角运行按钮，或按 `Cmd + R` 启动。

首次启动时，App 会自动完成以下初始化：

- 创建本地 SQLite 数据表
- 从 `mock_files.json` 加载初始文件数据
- 当数据库为空时写入 mock 数据，避免每次启动都覆盖用户操作

### 方式二：命令行构建

```bash
# 构建到模拟器（仅编译，不运行）
xcodebuild -project CloudDisk.xcodeproj \
           -scheme CloudDisk \
           -sdk iphonesimulator \
           -configuration Debug \
           build

# 指定模拟器构建
xcodebuild -project CloudDisk.xcodeproj \
           -scheme CloudDisk \
           -destination 'platform=iOS Simulator,name=iPhone 15' \
           build
```

### 真机运行说明

真机运行通常需要本地 Apple Developer 签名环境：

1. 打开 `Xcode -> Settings -> Accounts`，登录 Apple ID。
2. 在项目 `Signing & Capabilities` 中选择你的开发团队。
3. 将 `Bundle Identifier` 调整为唯一值，例如 `com.yourname.CloudDisk`。
4. 首次安装到设备后，根据系统提示在设备中信任开发者证书。

---

## DeepLink 测试

App 支持通过 `clouddisk://share?id=<shareId>` 唤起分享落地页。

### 在 App 内生成分享链接

1. 进入底部「文件」Tab。
2. 点击任意文件或文件夹的操作菜单。
3. 选择「分享链接」。
4. App 会生成并复制 `clouddisk://share?id=...`。

### 在模拟器中测试

```bash
xcrun simctl openurl booted "clouddisk://share?id=share_xxxxxxxx"
```

将其中的 `share_xxxxxxxx` 替换为 App 内实际生成的分享 ID 即可。

---

## 数据说明

项目核心数据表如下：

### `files`

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

### `share_records`

```text
share_id
file_id
created_at
```

数据流大致如下：

```text
mock_files.json -> MockNetworkService -> FileRepository -> DatabaseService -> SQLite -> ViewModel -> SwiftUI
```

---

## 注意事项

- 项目不依赖任何外部 Swift Package，无需执行 `pod install` 或 `swift package resolve`
- Mock 数据只会在数据库为空时导入一次，重新安装 App 或清空沙盒后会重置
- 上传的文件会复制到沙盒 `Documents/CloudDiskFiles/` 目录，卸载 App 后会一并清除
- 视频播放支持 `.mp4`、`.mov`、`.m4v` 格式；文本阅读主要面向 `.txt` 文件
- 分享记录保存在本地数据库中，当前不支持跨设备访问

---

## 后续可扩展方向

- 增加文件操作相关的 XCTest 单元测试
- 优化 txt 阅读器分页逻辑，提升排版准确性
- 如需跨设备分享，可引入服务端或云端映射能力
