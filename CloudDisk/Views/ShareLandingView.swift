import SwiftUI

/// DeepLink 拉起后的分享文件页。
///
/// 用户打开 clouddisk://share?id=xxx 后：
/// 1. AppRouter 解析出 shareId。
/// 2. ContentView 弹出 ShareLandingView。
/// 3. ShareLandingView 根据 shareId 查询数据库。
/// 4. 如果分享的是文件夹，展示文件夹内文件；如果分享的是单个文件，展示该文件。
struct ShareLandingView: View {
    let shareId: String
    let repository: FileRepository

    @Environment(\.dismiss) private var dismiss
    @State private var title = "分享文件"
    @State private var files: [FileItem] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    ContentUnavailableView(
                        "分享不可用",
                        systemImage: "link.badge.plus",
                        description: Text(errorMessage)
                    )
                } else {
                    ForEach(files) { file in
                        FileRowView(file: file)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .task {
                // 页面出现时根据 shareId 加载分享内容。
                await load()
            }
        }
    }

    /// 根据 shareId 查询分享记录并加载要展示的文件。
    private func load() async {
        isLoading = true
        errorMessage = nil

        do {
            try await repository.prepareInitialData()
            guard let sharedFile = try await repository.sharedFile(shareId: shareId) else {
                errorMessage = "找不到对应的分享记录"
                isLoading = false
                return
            }

            title = sharedFile.name
            if sharedFile.type == .folder {
                // 分享的是文件夹：展示它的子文件列表。
                files = try await repository.files(parentId: sharedFile.fileId)
            } else {
                // 分享的是单个文件：只展示这一项。
                files = [sharedFile]
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

struct ShareLandingView_Previews: PreviewProvider {
    static var previews: some View {
        ShareLandingView(shareId: "share_preview", repository: FileRepository())
    }
}
