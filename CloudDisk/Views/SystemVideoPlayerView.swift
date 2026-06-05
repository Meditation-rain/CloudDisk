import AVKit
import SwiftUI

/// 系统视频播放器页面。
///
/// 项目没有自定义播放器，而是使用 iOS 提供的 AVPlayerViewController。
/// 这是更稳妥的实现方式：系统播放器自带播放、暂停、进度条、全屏等能力。
struct SystemVideoPlayerView: View {
    let file: FileItem

    var body: some View {
        AVPlayerController(player: AVPlayer(url: videoURL))
            .ignoresSafeArea(edges: .bottom)
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 解析视频 URL。
    ///
    /// 查找顺序：
    /// 1. 如果 file.path 是真实沙盒文件路径，直接播放这个文件。
    /// 2. 如果 Bundle 中存在 fileId.mp4，例如 video_demo.mp4，播放内置视频。
    /// 3. 尝试根据 path 推导资源名。
    /// 4. 兜底返回 file.path，让播放器自己处理失败状态。
    private var videoURL: URL {
        if FileManager.default.fileExists(atPath: file.path) {
            return URL(fileURLWithPath: file.path)
        }

        if let demoURL = Bundle.main.url(forResource: file.fileId, withExtension: "mp4") {
            return demoURL
        }

        let resourceName = (file.path as NSString).deletingPathExtension
        if let bundledURL = Bundle.main.url(forResource: resourceName, withExtension: "mp4") {
            return bundledURL
        }

        return URL(fileURLWithPath: file.path)
    }
}

/// SwiftUI 和 UIKit 的桥接层。
///
/// AVPlayerViewController 是 UIKit 控件，SwiftUI 不能直接展示。
/// UIViewControllerRepresentable 可以把 UIKit 控制器包装成 SwiftUI View。
private struct AVPlayerController: UIViewControllerRepresentable {
    let player: AVPlayer

    /// 创建 UIKit 播放器控制器。
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        return controller
    }

    /// SwiftUI 状态变化时更新 UIKit 控制器。
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
    }
}

struct SystemVideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SystemVideoPlayerView(
                file: FileItem(
                    fileId: "video_demo",
                    name: "产品演示.mp4",
                    size: 52_428_800,
                    path: "/视频收藏/产品演示.mp4",
                    type: .video,
                    parentId: nil,
                    timestamp: Date(),
                    lastOpenedAt: nil,
                    savedAt: nil
                )
            )
        }
    }
}
