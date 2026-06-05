import Foundation

/// App 级路由状态。
///
/// 当前只处理 DeepLink 分享：
/// clouddisk://share?id=share_xxx
///
/// AppRouter 不负责展示页面，只负责把 URL 解析成 pendingShareId。
/// ContentView 监听 pendingShareId 后弹出 ShareLandingView。
@MainActor
final class AppRouter: ObservableObject {
    @Published var pendingShareId: String?

    /// 处理系统传进来的 URL Scheme。
    func handle(url: URL) {
        guard url.scheme == "clouddisk", url.host == "share" else {
            return
        }

        // URLComponents 用于解析 query 参数。
        // 例如 clouddisk://share?id=abc 中，id 的值就是 abc。
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        pendingShareId = components?.queryItems?.first(where: { $0.name == "id" })?.value
    }
}
