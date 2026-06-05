import SwiftUI

/// App 的根页面。
///
/// 这里负责两件事：
/// 1. 搭建底部 Tab：网盘首页 + 文件列表。
/// 2. 监听 AppRouter 的 DeepLink 状态，收到分享 id 后弹出分享页面。
struct ContentView: View {
    // 由 CloudDiskApp 注入，保证首页和文件页访问的是同一套数据层。
    let repository: FileRepository

    // router.pendingShareId 变化时，下面的 sheet 会自动弹出分享文件页。
    @ObservedObject var router: AppRouter

    var body: some View {
        TabView {
            // 首页：展示个人信息、容量、最近转存、最近浏览。
            HomeView(viewModel: HomeViewModel(repository: repository))
                .tabItem {
                    Label("网盘", systemImage: "externaldrive")
                }

            // 文件页：展示文件列表，并承载上传、打开、移动、删除、分享等主要操作。
            FileBrowserView(viewModel: FileBrowserViewModel(repository: repository))
                .tabItem {
                    Label("文件", systemImage: "folder")
                }
        }
        .sheet(item: shareIdBinding) { shareId in
            ShareLandingView(shareId: shareId.value, repository: repository)
        }
    }

    // SwiftUI 的 sheet(item:) 需要绑定一个 Identifiable?。
    // router 里保存的是 String?，所以这里把 String 包装成 ShareId。
    // 当 pendingShareId 为 nil 时，sheet 自动关闭。
    private var shareIdBinding: Binding<ShareId?> {
        Binding(
            get: {
                guard let pendingShareId = router.pendingShareId else { return nil }
                return ShareId(value: pendingShareId)
            },
            set: { value in
                if value == nil {
                    router.pendingShareId = nil
                }
            }
        )
    }
}

// Preview 只用于 Xcode 右侧 Canvas 预览页面，不参与正式业务逻辑。
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(repository: FileRepository(), router: AppRouter())
    }
}

// 用于适配 sheet(item:) 的轻量包装类型。
private struct ShareId: Identifiable, Equatable {
    let value: String
    var id: String { value }
}
