# CloudDisk 交付说明

## 项目目标

实现一个简易个人网盘 iOS 客户端，覆盖移动端 UI、SQLite 本地存储、模拟网络请求、文件夹浏览、txt 阅读器、系统播放器、文件管理和 DeepLink 分享。

## 阶段完成情况

### 第 1-3 阶段

- SwiftUI 工程骨架
- Tab 页面
- 数据模型
- SQLite 初始化
- mock JSON 数据解析
- 文件列表
- 文件夹层级浏览

### 第 4-5 阶段

- txt 文件打开
- 系统视频播放器入口
- 最近浏览更新
- txt 阅读器分页
- 左右滑动翻页
- 页码显示与边界处理

### 第 7-9 阶段

- 上传本地文件
- 文件重命名
- 文件移动
- 文件删除
- 分享链接生成
- DeepLink 解析
- 分享文件页
- 首页个人信息、最近转存、最近浏览展示

### 第 10-12 阶段

- 数据库读写在后台队列执行
- 页面使用 async/await 加载数据
- 加载态、错误态、完成提示
- 文件行补充时间展示
- README 完善
- 测试清单整理
- 交付说明整理

## 架构说明

项目采用轻量 MVVM + Repository 分层：

- `Views`：SwiftUI 页面展示与用户操作入口。
- `ViewModels`：页面状态、加载状态、错误信息和交互逻辑。
- `Repositories`：统一封装数据访问。
- `Services`：SQLite、mock 网络和文本读取。
- `Models`：文件、分享记录等数据结构。

这种结构足够清晰，适合课程答辩说明，也便于后续继续扩展更多文件类型。

## 数据流

启动时：

```text
mock_files.json -> MockNetworkService -> FileRepository -> DatabaseService -> SQLite -> ViewModel -> SwiftUI
```

打开文件时：

```text
用户点击文件 -> ViewModel -> Repository -> 更新 last_opened_at -> 首页最近浏览刷新
```

分享时：

```text
用户选择分享 -> 创建 share_records -> 生成 clouddisk://share?id=xxx -> DeepLink 拉起 -> 查询分享记录 -> 展示分享页
```

## 运行方式

1. 打开 `CloudDisk.xcodeproj`。
2. 选择 `CloudDisk` scheme。
3. 选择 iPhone 模拟器。
4. 按 `Cmd + R` 运行。

## 推荐演示顺序

1. 展示首页：个人信息、最近转存、最近浏览。
2. 进入文件页：展示文件夹、txt、视频。
3. 点击文件夹进入子目录，再返回上一级。
4. 打开 txt，演示左右滑动翻页。
5. 返回首页，观察最近浏览变化。
6. 长按文件，演示重命名、移动、删除。
7. 长按文件，生成分享链接。
8. 在 Safari 输入分享链接，演示 DeepLink 拉起 App。

## 当前未实现项

- 广告 SDK。
- 服务端。
- 自定义播放器。
- KMP + MVI。

## 后续建议

- 增加 XCTest 单元测试目标。
- 将 txt 分页升级为基于实际排版结果的分页。
- 分享功能如需跨设备，应增加服务端或云端映射。
