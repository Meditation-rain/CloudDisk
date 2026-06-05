import Foundation

/// txt 内容读取服务。
///
/// 阅读器只关心“拿到文本内容”，不关心文本来自哪里。
/// 因此这里封装读取逻辑：
/// - 优先读取 Bundle 内置 txt。
/// - 如果是上传文件，则读取沙盒路径下的真实 txt。
/// - 都失败时返回一段兜底文本，避免阅读器空白。
struct TextContentService {
    func loadContent(for file: FileItem) -> String {
        // mock 文件使用 fileId 作为资源名，例如 txt_readme.txt。
        if let bundledContent = bundledText(named: file.fileId) {
            return bundledContent
        }

        // 上传的 txt 文件会保存在 App 沙盒，file.path 是真实路径。
        if FileManager.default.fileExists(atPath: file.path),
           let localContent = try? String(contentsOfFile: file.path, encoding: .utf8) {
            return localContent
        }

        return """
        \(file.name)

        暂未找到对应的文本文件内容。

        当前页面仍会展示阅读器分页、左右滑动翻页、页码边界等核心能力。后续接入上传功能后，沙盒内的真实 txt 文件会从本地路径读取。
        """
    }

    /// 从 App Bundle 中读取内置 txt 资源。
    private func bundledText(named name: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt") else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
