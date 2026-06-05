import Foundation

/// 数据仓库层。
///
/// Repository 位于 ViewModel 和 Service 之间：
/// - ViewModel 不直接碰 SQLite 和文件系统。
/// - DatabaseService 只负责数据库读写。
/// - FileRepository 负责把多个底层动作组合成一个业务动作。
///
/// 例子：
/// 上传文件不是单纯插入数据库，它还包括：
/// 1. 访问系统文件选择器返回的安全 URL。
/// 2. 复制文件到 App 沙盒。
/// 3. 获取文件大小。
/// 4. 根据扩展名识别类型。
/// 5. 写入 SQLite。
final class FileRepository {
    private let database: DatabaseService
    private let mockNetwork: MockNetworkService

    init(
        database: DatabaseService = DatabaseService(),
        mockNetwork: MockNetworkService = MockNetworkService()
    ) {
        self.database = database
        self.mockNetwork = mockNetwork
    }

    /// 初始化 mock 数据。
    /// 首次启动时，mock_files.json 会写入 SQLite。
    /// 数据库已有记录时会跳过，避免每次启动都重置用户操作。
    func prepareInitialData() async throws {
        let files = try await mockNetwork.fetchInitialFiles()
        try await database.insertFilesIfEmpty(files)
    }

    /// 查询某个目录下的文件。
    /// parentId 为 nil 表示根目录。
    func files(parentId: String?) async throws -> [FileItem] {
        try await database.fetchFiles(parentId: parentId)
    }

    func file(fileId: String) async throws -> FileItem? {
        try await database.fetchFile(fileId: fileId)
    }

    func folders() async throws -> [FileItem] {
        try await database.fetchFolders()
    }

    /// 首页“最近浏览”。
    /// 实际上是按 files.last_opened_at 倒序查询。
    func recentOpened(limit: Int = 6) async throws -> [FileItem] {
        try await database.fetchRecentOpened(limit: limit)
    }

    /// 首页“最近转存”。
    /// 实际上是按 files.saved_at 倒序查询。
    func recentSaved(limit: Int = 6) async throws -> [FileItem] {
        try await database.fetchRecentSaved(limit: limit)
    }

    /// 首页容量统计。
    /// 主要用于计算 “已使用容量 / 10GB” 的进度条。
    func databaseStats() async throws -> DatabaseStats {
        try await database.fetchStats()
    }

    /// 标记文件被打开过。
    /// txt 和视频打开时都会调用这个方法，从而更新最近浏览。
    func markOpened(_ file: FileItem) async throws {
        try await database.updateLastOpened(fileId: file.fileId, date: Date())
    }

    /// 上传本地文件。
    /// sourceURL 是系统文件选择器返回的 URL。
    /// 这个 URL 不一定属于本 App，所以需要先复制到 App 自己的 Documents 目录。
    func uploadFile(from sourceURL: URL, to parentId: String?) async throws {
        let copiedURL = try copyToAppStorage(sourceURL)
        let attributes = try FileManager.default.attributesOfItem(atPath: copiedURL.path)
        let size = attributes[.size] as? Int64 ?? 0
        let now = Date()

        let file = FileItem(
            fileId: "upload_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())",
            name: copiedURL.lastPathComponent,
            size: size,
            path: copiedURL.path,
            type: fileType(for: copiedURL),
            parentId: parentId,
            timestamp: now,
            lastOpenedAt: nil,
            savedAt: now
        )

        try await database.insertFile(file)
    }

    /// 重命名只修改数据库中的 name 字段。
    /// 当前实现不重命名沙盒中的真实文件，因为页面展示以数据库 name 为准。
    func rename(_ file: FileItem, to newName: String) async throws {
        try await database.renameFile(fileId: file.fileId, newName: newName)
    }

    /// 移动文件本质是修改 parent_id。
    /// parentId 为 nil 表示移动到根目录。
    func move(_ file: FileItem, to parentId: String?) async throws {
        try await database.moveFile(fileId: file.fileId, to: parentId)
    }

    /// 删除文件。
    /// 数据库记录一定会删除；如果是上传到沙盒的真实文件，也尝试删除物理文件。
    func delete(_ file: FileItem) async throws {
        try await database.deleteFile(fileId: file.fileId)

        if file.type != .folder && FileManager.default.fileExists(atPath: file.path) {
            try? FileManager.default.removeItem(atPath: file.path)
        }
    }

    /// 创建分享链接。
    /// 注意链接里只放 shareId，不直接暴露文件名或文件路径。
    func shareLink(for file: FileItem) async throws -> URL {
        let record = try await database.createShareRecord(fileId: file.fileId)
        return URL(string: "clouddisk://share?id=\(record.shareId)")!
    }

    /// 根据分享 id 查询对应文件。
    /// DeepLink 页面会使用这个方法找到要展示的文件或文件夹。
    func sharedFile(shareId: String) async throws -> FileItem? {
        guard let record = try await database.fetchShareRecord(shareId: shareId) else {
            return nil
        }
        return try await database.fetchFile(fileId: record.fileId)
    }

    /// 把系统文件选择器选中的文件复制到 App 沙盒。
    ///
    /// iOS App 不能长期依赖外部文件 URL。
    /// 正确做法是把文件复制到自己的 Documents 目录，后续读取和播放都使用沙盒路径。
    private func copyToAppStorage(_ sourceURL: URL) throws -> URL {
        // 某些文件来自系统文件选择器或 iCloud，需要通过安全作用域访问。
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default
        let directory = fileManager
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CloudDiskFiles", isDirectory: true)

        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let destination = uniqueDestinationURL(
            in: directory,
            fileName: sourceURL.lastPathComponent.isEmpty ? "未命名文件" : sourceURL.lastPathComponent
        )
        try fileManager.copyItem(at: sourceURL, to: destination)
        return destination
    }

    /// 生成不冲突的目标路径。
    /// 如果用户上传了同名文件，会自动变成 xxx-1.txt、xxx-2.txt。
    private func uniqueDestinationURL(in directory: URL, fileName: String) -> URL {
        let fileManager = FileManager.default
        let baseURL = directory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: baseURL.path) else {
            return baseURL
        }

        let fileExtension = baseURL.pathExtension
        let baseName = baseURL.deletingPathExtension().lastPathComponent

        for index in 1...999 {
            let candidateName: String
            if fileExtension.isEmpty {
                candidateName = "\(baseName)-\(index)"
            } else {
                candidateName = "\(baseName)-\(index).\(fileExtension)"
            }

            let candidateURL = directory.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
        }

        return directory.appendingPathComponent("\(UUID().uuidString)-\(fileName)")
    }

    /// 根据扩展名判断文件类型。
    /// 这里只实现课程需求里用到的 txt 和视频类型。
    private func fileType(for url: URL) -> FileType {
        switch url.pathExtension.lowercased() {
        case "txt":
            return .txt
        case "mp4", "mov", "m4v":
            return .video
        default:
            return .other
        }
    }
}
