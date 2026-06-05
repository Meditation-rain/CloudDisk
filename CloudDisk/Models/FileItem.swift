import Foundation

/// 网盘文件类型。
///
/// 数据库中保存的是 rawValue，例如 "folder"、"txt"。
/// 页面展示时再转换成中文名称和系统图标。
enum FileType: String, Codable, CaseIterable {
    case folder
    case video
    case txt
    case other

    /// 展示在文件行副标题中的中文类型。
    var displayName: String {
        switch self {
        case .folder: return "文件夹"
        case .video: return "视频"
        case .txt: return "文本"
        case .other: return "其他"
        }
    }

    /// 文件行左侧使用的 SF Symbol 图标名。
    var systemImage: String {
        switch self {
        case .folder: return "folder.fill"
        case .video: return "play.rectangle.fill"
        case .txt: return "doc.text.fill"
        case .other: return "doc.fill"
        }
    }
}

/// 网盘中的一个文件或文件夹。
///
/// 这个结构体同时服务三层：
/// - JSON 解码：mock_files.json 会解码成 FileItem。
/// - SQLite 映射：files 表中的一行会转换成 FileItem。
/// - SwiftUI 展示：List/首页卡片直接展示 FileItem。
struct FileItem: Identifiable, Codable, Hashable {
    // 文件唯一 id。上传文件时使用 UUID 生成；mock 数据里手动指定。
    let fileId: String

    // 文件名，例如 "项目说明.txt"。
    var name: String

    // 文件大小，单位是 byte。文件夹大小固定为 0。
    var size: Int64

    // 文件路径。mock 文件可能是模拟路径；上传文件则是真实沙盒路径。
    var path: String

    // 文件类型，决定点击后进入文件夹、阅读器、播放器还是不处理。
    var type: FileType

    // 父文件夹 id。
    // nil 表示根目录；非 nil 表示这个文件属于某个文件夹。
    var parentId: String?

    // 文件创建/初始化时间，用于列表排序和展示。
    var timestamp: Date

    // 最近浏览时间。打开 txt 或视频后更新。
    var lastOpenedAt: Date?

    // 最近转存/上传时间。mock 初始化和上传文件时写入。
    var savedAt: Date?

    // SwiftUI List 需要 Identifiable，这里直接使用 fileId 作为稳定 id。
    var id: String { fileId }

    // 将 byte 转成人能读懂的大小，例如 4096 -> 4 KB。
    var formattedSize: String {
        guard type != .folder else { return "--" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    // 列表展示用的时间字符串。
    var formattedTimestamp: String {
        Self.dateFormatter.string(from: timestamp)
    }

    // DateFormatter 创建成本较高，所以做成 static，只初始化一次。
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}
