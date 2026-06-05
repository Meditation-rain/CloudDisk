import Foundation
import SQLite3

/// SQLite 数据访问层。
///
/// 这个类只负责“如何和 SQLite 交互”，不负责页面逻辑。
/// 所有 SQL 都集中在这里，方便查看数据库设计和排查数据问题。
final class DatabaseService {
    // sqlite3_open 返回的数据库连接指针。
    private var db: OpaquePointer?

    // SQLite 本身可以被多线程访问，但手写 sqlite3 API 时保持串行更安全。
    // 所有数据库读写都通过 run(...) 丢到这个队列执行，避免阻塞主线程。
    private let queue = DispatchQueue(label: "cloud.disk.database.queue")

    // 保存数据库文件路径，便于调试或统计时查看。
    private var databaseURL: URL?

    init() {
        // 初始化时打开数据库并创建表。
        // 如果表已存在，CREATE TABLE IF NOT EXISTS 不会重复创建。
        openDatabase()
        createTables()
    }

    deinit {
        sqlite3_close(db)
    }

    /// 查询某个文件夹下的文件。
    /// parentId 为 nil 时查询根目录；非 nil 时查询指定文件夹的子文件。
    func fetchFiles(parentId: String?) async throws -> [FileItem] {
        try await run {
            let sql: String
            if parentId == nil {
                sql = "SELECT file_id, name, size, path, type, parent_id, timestamp, last_opened_at, saved_at FROM files WHERE parent_id IS NULL ORDER BY type = 'folder' DESC, timestamp DESC"
            } else {
                sql = "SELECT file_id, name, size, path, type, parent_id, timestamp, last_opened_at, saved_at FROM files WHERE parent_id = ? ORDER BY type = 'folder' DESC, timestamp DESC"
            }

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(message: self.lastErrorMessage())
            }
            defer { sqlite3_finalize(statement) }

            if let parentId {
                sqlite3_bind_text(statement, 1, parentId, -1, transientDestructor)
            }

            var files: [FileItem] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                files.append(self.readFile(from: statement))
            }
            return files
        }
    }

    /// 根据 fileId 查询单个文件。
    /// DeepLink 分享页会用它根据 share_records.file_id 找到真实文件。
    func fetchFile(fileId: String) async throws -> FileItem? {
        try await run {
            let sql = "SELECT file_id, name, size, path, type, parent_id, timestamp, last_opened_at, saved_at FROM files WHERE file_id = ? LIMIT 1"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(message: self.lastErrorMessage())
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, fileId, -1, transientDestructor)
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            return self.readFile(from: statement)
        }
    }

    /// 查询所有文件夹。
    /// 移动文件时需要列出可选目标文件夹。
    func fetchFolders() async throws -> [FileItem] {
        try await run {
            let sql = "SELECT file_id, name, size, path, type, parent_id, timestamp, last_opened_at, saved_at FROM files WHERE type = 'folder' ORDER BY name ASC"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(message: self.lastErrorMessage())
            }
            defer { sqlite3_finalize(statement) }

            var folders: [FileItem] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                folders.append(self.readFile(from: statement))
            }
            return folders
        }
    }

    func fetchRecentOpened(limit: Int) async throws -> [FileItem] {
        try await fetchRecent(column: "last_opened_at", limit: limit)
    }

    func fetchRecentSaved(limit: Int) async throws -> [FileItem] {
        try await fetchRecent(column: "saved_at", limit: limit)
    }

    /// 查询数据库统计信息。
    /// 首页容量进度条使用 totalSize / 10GB 计算。
    func fetchStats() async throws -> DatabaseStats {
        try await run {
            DatabaseStats(
                fileCount: try self.count(sql: "SELECT COUNT(*) FROM files"),
                folderCount: try self.count(sql: "SELECT COUNT(*) FROM files WHERE type = 'folder'"),
                totalSize: try self.totalSize(),
                shareCount: try self.count(sql: "SELECT COUNT(*) FROM share_records"),
                databasePath: self.databaseURL?.path ?? ""
            )
        }
    }

    /// 插入一个文件。
    /// 上传文件时会调用这个方法。
    func insertFile(_ file: FileItem) async throws {
        try await run {
            try self.insert(file)
        }
    }

    /// 更新最近浏览时间。
    /// 打开 txt 或视频后调用。
    func updateLastOpened(fileId: String, date: Date) async throws {
        try await run {
            let sql = "UPDATE files SET last_opened_at = ? WHERE file_id = ?"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(message: self.lastErrorMessage())
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_double(statement, 1, date.timeIntervalSince1970)
            sqlite3_bind_text(statement, 2, fileId, -1, transientDestructor)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.updateFailed(message: self.lastErrorMessage())
            }
        }
    }

    /// 重命名文件。
    /// 这里只更新数据库 name 字段。
    func renameFile(fileId: String, newName: String) async throws {
        try await run {
            let sql = "UPDATE files SET name = ? WHERE file_id = ?"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(message: self.lastErrorMessage())
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, newName, -1, transientDestructor)
            sqlite3_bind_text(statement, 2, fileId, -1, transientDestructor)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.updateFailed(message: self.lastErrorMessage())
            }
        }
    }

    /// 移动文件。
    /// 移动的数据库含义就是修改 parent_id。
    func moveFile(fileId: String, to parentId: String?) async throws {
        try await run {
            if let parentId, try self.isInvalidMove(fileId: fileId, targetParentId: parentId) {
                throw DatabaseError.invalidMove
            }

            let sql = "UPDATE files SET parent_id = ? WHERE file_id = ?"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(message: self.lastErrorMessage())
            }
            defer { sqlite3_finalize(statement) }

            if let parentId {
                sqlite3_bind_text(statement, 1, parentId, -1, transientDestructor)
            } else {
                sqlite3_bind_null(statement, 1)
            }
            sqlite3_bind_text(statement, 2, fileId, -1, transientDestructor)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.updateFailed(message: self.lastErrorMessage())
            }
        }
    }

    /// 删除文件或文件夹。
    /// 使用递归 CTE 找出目标文件夹的所有子文件，然后一次性删除。
    func deleteFile(fileId: String) async throws {
        try await run {
            let sql = """
            WITH RECURSIVE descendants(file_id) AS (
                SELECT file_id FROM files WHERE file_id = ?
                UNION ALL
                SELECT files.file_id FROM files
                INNER JOIN descendants ON files.parent_id = descendants.file_id
            )
            DELETE FROM files WHERE file_id IN (SELECT file_id FROM descendants)
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(message: self.lastErrorMessage())
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, fileId, -1, transientDestructor)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.deleteFailed(message: self.lastErrorMessage())
            }
        }
    }

    /// 创建分享记录。
    /// share_records 表把 shareId 映射到 fileId。
    func createShareRecord(fileId: String) async throws -> ShareRecord {
        try await run {
            let record = ShareRecord(
                shareId: "share_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())",
                fileId: fileId,
                createdAt: Date()
            )
            let sql = "INSERT INTO share_records (share_id, file_id, created_at) VALUES (?, ?, ?)"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(message: self.lastErrorMessage())
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, record.shareId, -1, transientDestructor)
            sqlite3_bind_text(statement, 2, record.fileId, -1, transientDestructor)
            sqlite3_bind_double(statement, 3, record.createdAt.timeIntervalSince1970)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.insertFailed(message: self.lastErrorMessage())
            }
            return record
        }
    }

    /// 根据 shareId 查询分享记录。
    /// DeepLink 只携带 shareId，不能直接暴露文件名或路径。
    func fetchShareRecord(shareId: String) async throws -> ShareRecord? {
        try await run {
            let sql = "SELECT share_id, file_id, created_at FROM share_records WHERE share_id = ? LIMIT 1"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(message: self.lastErrorMessage())
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, shareId, -1, transientDestructor)
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            return ShareRecord(
                shareId: self.textValue(statement, index: 0),
                fileId: self.textValue(statement, index: 1),
                createdAt: self.dateValue(statement, index: 2) ?? Date()
            )
        }
    }

    /// 首次启动时插入 mock 文件。
    /// 如果 files 表已经有记录，说明 App 已初始化或用户已经操作过数据，此时不覆盖。
    func insertFilesIfEmpty(_ files: [FileItem]) async throws {
        try await run {
            let count = try self.fileCount()
            guard count == 0 else { return }

            for file in files {
                try self.insert(file)
            }
        }
    }

    /// 查询最近浏览或最近转存。
    /// column 只能由本类内部传入固定值，避免外部拼 SQL。
    private func fetchRecent(column: String, limit: Int) async throws -> [FileItem] {
        try await run {
            let sql = "SELECT file_id, name, size, path, type, parent_id, timestamp, last_opened_at, saved_at FROM files WHERE \(column) IS NOT NULL ORDER BY \(column) DESC LIMIT ?"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(message: self.lastErrorMessage())
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_int(statement, 1, Int32(limit))

            var files: [FileItem] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                files.append(self.readFile(from: statement))
            }
            return files
        }
    }

    /// 打开 SQLite 数据库文件。
    /// iOS App 的 Documents 目录可读写，适合保存用户数据。
    private func openDatabase() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = directory.appendingPathComponent("CloudDisk.sqlite")
        databaseURL = url
        sqlite3_open(url.path, &db)
    }

    /// 创建数据库表。
    ///
    /// files：保存文件和文件夹。
    /// share_records：保存分享链接和文件的映射。
    private func createTables() {
        let sql = """
        CREATE TABLE IF NOT EXISTS files (
            file_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            size INTEGER NOT NULL,
            path TEXT NOT NULL,
            type TEXT NOT NULL,
            parent_id TEXT,
            timestamp REAL NOT NULL,
            last_opened_at REAL,
            saved_at REAL
        );
        CREATE TABLE IF NOT EXISTS share_records (
            share_id TEXT PRIMARY KEY,
            file_id TEXT NOT NULL,
            created_at REAL NOT NULL
        );
        """
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func fileCount() throws -> Int {
        try count(sql: "SELECT COUNT(*) FROM files")
    }

    private func count(sql: String) throws -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(statement, 0))
    }

    private func totalSize() throws -> Int64 {
        let sql = "SELECT COALESCE(SUM(size), 0) FROM files WHERE type != 'folder'"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return sqlite3_column_int64(statement, 0)
    }

    /// 底层插入逻辑。
    /// mock 初始化和上传文件都会复用它。
    private func insert(_ file: FileItem) throws {
        let sql = """
        INSERT INTO files (file_id, name, size, path, type, parent_id, timestamp, last_opened_at, saved_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, file.fileId, -1, transientDestructor)
        sqlite3_bind_text(statement, 2, file.name, -1, transientDestructor)
        sqlite3_bind_int64(statement, 3, file.size)
        sqlite3_bind_text(statement, 4, file.path, -1, transientDestructor)
        sqlite3_bind_text(statement, 5, file.type.rawValue, -1, transientDestructor)
        bindOptionalText(statement, index: 6, value: file.parentId)
        sqlite3_bind_double(statement, 7, file.timestamp.timeIntervalSince1970)
        bindOptionalDate(statement, index: 8, value: file.lastOpenedAt)
        bindOptionalDate(statement, index: 9, value: file.savedAt)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.insertFailed(message: lastErrorMessage())
        }
    }

    /// 判断移动是否合法。
    /// 文件夹不能移动到自己或自己的子文件夹中，否则会形成循环目录。
    private func isInvalidMove(fileId: String, targetParentId: String) throws -> Bool {
        if fileId == targetParentId {
            return true
        }

        let sql = """
        WITH RECURSIVE descendants(file_id) AS (
            SELECT file_id FROM files WHERE parent_id = ?
            UNION ALL
            SELECT files.file_id FROM files
            INNER JOIN descendants ON files.parent_id = descendants.file_id
        )
        SELECT COUNT(*) FROM descendants WHERE file_id = ?
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, fileId, -1, transientDestructor)
        sqlite3_bind_text(statement, 2, targetParentId, -1, transientDestructor)

        guard sqlite3_step(statement) == SQLITE_ROW else { return false }
        return sqlite3_column_int(statement, 0) > 0
    }

    /// 将 SQLite 当前行转换成 FileItem。
    /// 这里的字段顺序必须和 SELECT 语句中的字段顺序一致。
    private func readFile(from statement: OpaquePointer?) -> FileItem {
        FileItem(
            fileId: textValue(statement, index: 0),
            name: textValue(statement, index: 1),
            size: sqlite3_column_int64(statement, 2),
            path: textValue(statement, index: 3),
            type: FileType(rawValue: textValue(statement, index: 4)) ?? .other,
            parentId: optionalTextValue(statement, index: 5),
            timestamp: dateValue(statement, index: 6) ?? Date(),
            lastOpenedAt: dateValue(statement, index: 7),
            savedAt: dateValue(statement, index: 8)
        )
    }

    private func textValue(_ statement: OpaquePointer?, index: Int32) -> String {
        guard let pointer = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: pointer)
    }

    private func optionalTextValue(_ statement: OpaquePointer?, index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return textValue(statement, index: index)
    }

    private func dateValue(_ statement: OpaquePointer?, index: Int32) -> Date? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return Date(timeIntervalSince1970: sqlite3_column_double(statement, index))
    }

    private func bindOptionalText(_ statement: OpaquePointer?, index: Int32, value: String?) {
        if let value {
            sqlite3_bind_text(statement, index, value, -1, transientDestructor)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func bindOptionalDate(_ statement: OpaquePointer?, index: Int32, value: Date?) {
        if let value {
            sqlite3_bind_double(statement, index, value.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func run<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func lastErrorMessage() -> String {
        guard let message = sqlite3_errmsg(db) else { return "Unknown SQLite error" }
        return String(cString: message)
    }
}

private let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum DatabaseError: LocalizedError {
    case prepareFailed(message: String)
    case insertFailed(message: String)
    case updateFailed(message: String)
    case deleteFailed(message: String)
    case invalidMove

    var errorDescription: String? {
        switch self {
        case .prepareFailed(let message):
            return "数据库语句准备失败：\(message)"
        case .insertFailed(let message):
            return "数据库写入失败：\(message)"
        case .updateFailed(let message):
            return "数据库更新失败：\(message)"
        case .deleteFailed(let message):
            return "数据库删除失败：\(message)"
        case .invalidMove:
            return "不能移动到自身或子文件夹"
        }
    }
}
