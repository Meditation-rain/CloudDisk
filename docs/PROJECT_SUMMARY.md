# CloudDisk 项目总结

## 项目概述

CloudDisk 是一个基于 iOS SwiftUI 实现的简易个人网盘客户端。项目参考主流网盘产品的基础能力，重点实现文件列表、文件夹浏览、最近记录、txt 阅读器、视频播放、文件管理、SQLite 本地存储和 DeepLink 分享。

当前项目定位为课程项目 MVP，核心目标是展示移动端基础 UI、数据持久化、异步数据流、文件操作和页面跳转能力。

## 已完成功能

### 1. 首页

首页 Tab 名为 `网盘`，已实现：

- 个人信息展示
- 容量进度展示
- 最近转存列表
- 最近浏览列表
- 页面上下滚动
- 文件行图标、名称、类型、大小、时间展示

最近浏览会在打开 txt 或视频后更新。

### 2. 文件列表

文件 Tab 已实现：

- 根目录文件展示
- 文件夹展示
- txt 文件展示
- 视频文件展示
- 文件图标区、文本区对齐
- 点击文件夹进入子目录
- 返回上一级目录
- 空文件夹状态

当前 mock 数据中包含：

- `学习资料`
- `视频收藏`
- `项目说明.txt`
- `SwiftUI 笔记.txt`
- `SQLite 设计.txt`
- `产品演示.mp4`

### 3. txt 阅读器

已实现简易 txt 阅读器：

- 读取内置 txt 示例内容
- 根据屏幕尺寸估算分页
- 左滑下一页
- 右滑上一页
- 底部页码显示
- 上一页/下一页按钮
- 首页和末页边界禁用

### 4. 视频播放

已接入系统播放器：

- 使用 `AVPlayerViewController`
- 点击 `产品演示.mp4` 后进入播放器页面
- 已支持读取 `Resources/video_demo.mp4`

如果 `video_demo.mp4` 已加入工程资源，点击 mock 视频即可播放真实视频。

### 5. 最近浏览与最近转存

已实现：

- mock 数据初始化 `savedAt`，用于最近转存
- 打开 txt 或视频时更新 `lastOpenedAt`
- 首页按时间倒序展示最近浏览
- 首页按时间倒序展示最近转存

### 6. 文件管理

文件行右侧提供 `...` 操作按钮，同时保留长按菜单。

已实现：

- 上传本地文件
- 重命名
- 移动
- 删除
- 分享链接

移动支持：

- 移动到根目录
- 移动到其他文件夹
- 阻止移动到自身或子文件夹

删除支持：

- 删除单个文件
- 删除文件夹及其子文件

上传支持：

- 点击文件页右上角 `+`
- 调用系统文件选择器
- 将文件复制到 App 沙盒 `Documents/CloudDiskFiles`
- 根据扩展名识别 txt、视频或其他文件
- 写入 SQLite
- 更新最近转存

### 7. 分享与 DeepLink

已实现本地分享链路：

- 生成本地 `shareId`
- 分享链接格式：`clouddisk://share?id=share_xxx`
- 链接不包含文件名、路径等明文信息
- 分享链接自动复制到剪贴板
- 支持系统分享面板
- App 收到 DeepLink 后展示分享文件页

当前分享记录保存在本机 SQLite，不支持跨设备访问。

### 8. 文档与交付材料

已补充：

- `README.md`
- `docs/QA_CHECKLIST.md`
- `docs/DELIVERY_REPORT.md`
- `docs/PROJECT_SUMMARY.md`

## 使用的技术

### iOS 与 UI

- Swift
- SwiftUI
- NavigationStack
- TabView
- List
- ScrollView
- Menu
- Alert
- Sheet
- ShareLink

### 数据与存储

- SQLite3
- 本地数据库表 `files`
- 本地数据库表 `share_records`
- JSON 解码
- Bundle 资源读取

数据流：

```text
mock_files.json -> MockNetworkService -> FileRepository -> DatabaseService -> SQLite -> ViewModel -> SwiftUI
```

### 架构

项目采用轻量 MVVM + Repository：

- `Models`：数据结构
- `Views`：SwiftUI 页面
- `ViewModels`：页面状态与用户操作逻辑
- `Repositories`：统一数据访问入口
- `Services`：数据库、mock 网络、文本读取等底层能力

### 异步处理

- 使用 `async/await`
- 数据库读写放在串行后台队列
- UI 状态在主线程更新
- 页面提供 loading、错误提示和操作完成提示

### 文件与媒体

- txt 内容从 Bundle 资源读取
- 视频通过 `AVKit`
- 系统播放器使用 `AVPlayerViewController`

### DeepLink

- 使用 iOS URL Scheme
- Scheme：`clouddisk`
- 链接格式：`clouddisk://share?id=share_xxx`
- `onOpenURL` 接收链接
- `AppRouter` 解析分享参数并驱动页面展示

## 如何运行

1. 使用 Xcode 打开 `CloudDisk.xcodeproj`。
2. 选择 `CloudDisk` scheme。
3. 选择 iPhone 模拟器。
4. 按 `Cmd + R` 运行。

如果遇到旧数据影响展示，可以在模拟器里删除 CloudDisk App 后重新运行。

## 推荐演示路径

1. 打开 App，展示 `网盘` 首页。
2. 说明最近转存、最近浏览。
3. 进入 `文件` Tab。
4. 点击 `学习资料`，演示文件夹进入。
5. 点击 `返回上一级`。
6. 打开 `项目说明.txt`，演示左右滑动翻页。
7. 返回首页，展示最近浏览更新。
8. 进入 `视频收藏`，点击 `产品演示.mp4` 播放视频。
9. 返回文件列表，点击文件行右侧 `...`。
10. 演示重命名、移动、删除。
11. 演示生成分享链接。
12. 在 Safari 输入分享链接，演示 DeepLink 拉起 App。

## 当前未完成或限制

### 未完成

- 广告 SDK
- 服务端
- 自定义播放器
- KMP + MVI

### 限制

- 初始文件数据来自 mock JSON，上传后的文件来自设备本地文件。
- 分享链接只在本机有效，不能跨设备访问。
- txt 分页为估算分页，不是专业排版引擎。
- 视频播放依赖 `Resources/video_demo.mp4` 是否存在并加入 target。

## 项目完成度判断

当前项目已经完成大部分主线功能，包括：

- 首页
- 文件列表
- 文件夹浏览
- txt 阅读
- 视频播放
- 文件删除、移动、重命名
- 分享链接
- DeepLink
- SQLite 本地存储
- mock 网络数据流
- 上传本地文件

当前项目已经覆盖原始基础需求中的主要功能，包括上传、数据库、文件管理、阅读器、视频入口和 DeepLink 分享。拓展项如广告 SDK、服务端、自定义播放器和 KMP 暂未实现。
