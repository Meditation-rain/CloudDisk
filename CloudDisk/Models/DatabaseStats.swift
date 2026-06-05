import Foundation

struct DatabaseStats: Hashable {
    let fileCount: Int
    let folderCount: Int
    let totalSize: Int64
    let shareCount: Int
    let databasePath: String

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}
