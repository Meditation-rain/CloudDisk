import Foundation

/// 文件页的 ViewModel。
///
/// ViewModel 的职责：
/// - 保存页面状态，例如 files、loading、错误信息。
/// - 接收页面事件，例如打开文件、上传、重命名、移动、删除。
/// - 调用 Repository 完成真正的数据读写。
///
/// 这里标记 @MainActor，表示它的属性更新都发生在主线程，
/// SwiftUI 可以安全地监听 @Published 状态并刷新 UI。
@MainActor
final class FileBrowserViewModel: ObservableObject {
    // 当前目录下要展示的文件列表。
    @Published private(set) var files: [FileItem] = []

    // 所有文件夹，用于“移动文件”时选择目标文件夹。
    @Published private(set) var folders: [FileItem] = []

    // 当前文件夹路径栈。
    // 根目录为空；进入文件夹时 append；返回上一级时 removeLast。
    @Published private(set) var folderStack: [FileItem] = []

    // 控制页面 loading 状态。
    @Published var isLoading = false

    // 展示错误信息，例如数据库失败、上传失败。
    @Published var errorMessage: String?

    // 展示操作成功提示，例如上传成功、已移动。
    @Published var successMessage: String?

    private let repository: FileRepository

    init(repository: FileRepository) {
        self.repository = repository
    }

    var title: String {
        folderStack.last?.name ?? "全部文件"
    }

    // 是否可以返回上一级目录。
    var canGoBack: Bool {
        !folderStack.isEmpty
    }

    /// 加载当前目录文件。
    ///
    /// 注意这里每次都会先 prepareInitialData：
    /// - 如果数据库为空，会把 mock JSON 写入 SQLite。
    /// - 如果数据库已有数据，insertFilesIfEmpty 会直接跳过。
    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            try await repository.prepareInitialData()
            files = try await repository.files(parentId: folderStack.last?.fileId)
            folders = try await repository.folders()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 进入文件夹。
    /// 文件夹本身不作为新页面打开，而是改变 folderStack 后重新查询当前目录。
    func openFolder(_ folder: FileItem) async {
        guard folder.type == .folder else { return }
        folderStack.append(folder)
        await load()
    }

    /// 返回上一级目录。
    func goBack() async {
        guard canGoBack else { return }
        folderStack.removeLast()
        await load()
    }

    /// 打开文件或文件夹。
    ///
    /// - 文件夹：进入子目录，返回 nil。
    /// - txt：更新最近浏览，返回 .text，让 View 跳转阅读器。
    /// - video：更新最近浏览，返回 .video，让 View 跳转播放器。
    func openFile(_ file: FileItem) async -> FileOpenDestination? {
        guard file.type != .folder else {
            await openFolder(file)
            return nil
        }

        do {
            try await repository.markOpened(file)
            files = try await repository.files(parentId: folderStack.last?.fileId)
        } catch {
            errorMessage = error.localizedDescription
        }

        switch file.type {
        case .txt:
            return .text(file)
        case .video:
            return .video(file)
        case .other, .folder:
            return nil
        }
    }

    /// 重命名文件。
    /// 这里只校验“不能为空”，真正的数据库更新由 Repository/DatabaseService 完成。
    func rename(_ file: FileItem, to newName: String) async {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "文件名不能为空"
            return
        }

        do {
            isLoading = true
            try await repository.rename(file, to: trimmedName)
            await load()
            successMessage = "已重命名为 \(trimmedName)"
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// 删除文件。
    /// 如果删除的是文件夹，底层数据库会递归删除子文件。
    func delete(_ file: FileItem) async {
        do {
            isLoading = true
            try await repository.delete(file)
            await load()
            successMessage = "已删除 \(file.name)"
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// 移动文件到指定文件夹。
    /// parentId 为 nil 表示移动到根目录。
    func move(_ file: FileItem, to parentId: String?) async {
        do {
            isLoading = true
            try await repository.move(file, to: parentId)
            await load()
            successMessage = "已移动 \(file.name)"
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// 创建分享链接。
    /// 返回的 URL 类似 clouddisk://share?id=share_xxx。
    func shareLink(for file: FileItem) async -> URL? {
        do {
            let url = try await repository.shareLink(for: file)
            successMessage = "分享链接已复制"
            return url
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// 上传本地文件。
    /// Repository 会负责复制到 App 沙盒、识别文件类型、写入 SQLite。
    func uploadFile(from url: URL) async {
        do {
            isLoading = true
            try await repository.uploadFile(from: url, to: folderStack.last?.fileId)
            await load()
            successMessage = "上传成功"
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func clearSuccessMessage() {
        successMessage = nil
    }
}

/// 文件点击后的导航目的地。
/// ViewModel 不直接依赖 SwiftUI 页面类型，只返回“要去哪里”的业务枚举。
enum FileOpenDestination: Hashable {
    case text(FileItem)
    case video(FileItem)
}
