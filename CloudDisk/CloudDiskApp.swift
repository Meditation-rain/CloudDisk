import SwiftUI

@main
struct CloudDiskApp: App {
    // Repository 是整个 App 的数据入口。
    // 首页、文件页、分享页共用同一个 repository，避免各页面各自创建数据库连接和数据状态。
    private let repository = FileRepository()

    // AppRouter 专门处理 DeepLink 状态。
    // 例如用户打开 clouddisk://share?id=xxx 时，router 会保存 pendingShareId，
    // ContentView 监听到这个状态后弹出分享文件页。
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            ContentView(repository: repository, router: router)
                // iOS 收到 URL Scheme 时会回调这里。
                // 当前项目只处理 clouddisk://share?id=xxx 这种分享链接。
                .onOpenURL { url in
                    router.handle(url: url)
                }
        }
    }
}
