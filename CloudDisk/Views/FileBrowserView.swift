import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 文件浏览页。
///
/// 负责展示当前目录文件，并提供上传、打开、重命名、移动、删除、分享等操作。
/// 页面本身不直接操作数据库，所有业务动作都转发给 FileBrowserViewModel。
struct FileBrowserView: View {
    @StateObject var viewModel: FileBrowserViewModel

    // NavigationStack 路径。打开 txt 或视频时往这里追加目的地，SwiftUI 会自动跳转。
    @State private var path: [FileOpenDestination] = []

    // 以下状态用于控制弹窗、sheet 和文件选择器。
    @State private var renameFile: FileItem?
    @State private var renameText = ""
    @State private var deleteFile: FileItem?
    @State private var moveFile: FileItem?
    @State private var shareURL: ShareURL?
    @State private var isImporterPresented = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                // 进入子目录后提供返回上一级入口。
                if viewModel.canGoBack {
                    Button {
                        Task { await viewModel.goBack() }
                    } label: {
                        Label("返回上一级", systemImage: "chevron.left")
                    }
                }

                // 当前目录为空时显示空状态，否则展示文件列表。
                if viewModel.files.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView("文件夹为空", systemImage: "folder")
                } else {
                    ForEach(viewModel.files) { file in
                        FileListItem(file: file) {
                            Task {
                                // openFile 会根据类型决定行为：
                                // 文件夹直接进入；txt/video 返回导航目标。
                                if let destination = await viewModel.openFile(file) {
                                    path.append(destination)
                                }
                            }
                        } actions: {
                            // 右侧 ... 菜单。
                            fileActions(file)
                        }
                        .contextMenu {
                            // 长按菜单，作为备用入口。
                            fileActions(file)
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle(viewModel.title)
            // 根据 openFile 返回的目的地跳转阅读器或播放器。
            .navigationDestination(for: FileOpenDestination.self) { destination in
                switch destination {
                case .text(let file):
                    TextReaderView(file: file)
                case .video(let file):
                    SystemVideoPlayerView(file: file)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // 上传按钮：弹出系统文件选择器。
                    Button {
                        isImporterPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("上传文件")

                    // 手动刷新按钮，便于调试数据库变化。
                    Button {
                        Task { await viewModel.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("刷新")
                }
            }
            // 系统文件选择器。选择结果会交给 ViewModel 处理上传。
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task { await viewModel.uploadFile(from: url) }
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                }
            }
            .overlay {
                // 执行数据库或文件操作时显示加载状态。
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .task {
                // 页面首次出现时加载当前目录。
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load()
            }
            // 重命名弹窗。
            .alert("重命名", isPresented: renameBinding) {
                TextField("文件名", text: $renameText)
                Button("取消", role: .cancel) {
                    renameFile = nil
                }
                Button("保存") {
                    if let renameFile {
                        Task { await viewModel.rename(renameFile, to: renameText) }
                    }
                    renameFile = nil
                }
            } message: {
                Text("请输入新的文件名")
            }
            // 删除确认。删除属于破坏性操作，需要二次确认。
            .confirmationDialog("确认删除？", isPresented: deleteBinding) {
                if let file = deleteFile {
                    Button("删除 \(file.name)", role: .destructive) {
                        Task { await viewModel.delete(file) }
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                if let file = deleteFile {
                    Text(deleteMessage(for: file))
                }
            }
            // 移动文件时弹出目标文件夹选择页。
            .sheet(item: $moveFile) { file in
                MoveFileView(
                    file: file,
                    folders: viewModel.folders,
                    currentParentId: file.parentId
                ) { parentId in
                    Task { await viewModel.move(file, to: parentId) }
                }
            }
            // 分享结果页，展示 clouddisk://share?id=xxx。
            .sheet(item: $shareURL) { item in
                ShareLinkView(url: item.url)
            }
            // 操作成功提示。
            .alert("操作完成", isPresented: successBinding) {
                Button("知道了") {
                    viewModel.clearSuccessMessage()
                }
            } message: {
                Text(viewModel.successMessage ?? "")
            }
        }
    }

    // 把 renameFile 是否存在转换成 alert 需要的 Binding<Bool>。
    private var renameBinding: Binding<Bool> {
        Binding(
            get: { renameFile != nil },
            set: { if !$0 { renameFile = nil } }
        )
    }

    // 把 deleteFile 是否存在转换成 confirmationDialog 需要的 Binding<Bool>。
    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { deleteFile != nil },
            set: { if !$0 { deleteFile = nil } }
        )
    }

    // 把 successMessage 是否存在转换成 alert 展示状态。
    private var successBinding: Binding<Bool> {
        Binding(
            get: { viewModel.successMessage != nil },
            set: { if !$0 { viewModel.clearSuccessMessage() } }
        )
    }

    /// 文件操作菜单。右侧 ... 和长按菜单都复用这一组按钮。
    @ViewBuilder
    private func fileActions(_ file: FileItem) -> some View {
        Button {
            startRename(file)
        } label: {
            Label("重命名", systemImage: "pencil")
        }

        Button {
            moveFile = file
        } label: {
            Label("移动", systemImage: "folder")
        }

        Button {
            Task {
                if let url = await viewModel.shareLink(for: file) {
                    await MainActor.run {
                        UIPasteboard.general.string = url.absoluteString
                        shareURL = ShareURL(url: url)
                    }
                }
            }
        } label: {
            Label("分享链接", systemImage: "square.and.arrow.up")
        }

        Button(role: .destructive) {
            deleteFile = file
        } label: {
            Label("删除", systemImage: "trash")
        }
    }

    private func startRename(_ file: FileItem) {
        renameFile = file
        renameText = file.name
    }

    private func deleteMessage(for file: FileItem) -> String {
        file.type == .folder ? "删除文件夹会同时删除其中的文件。" : "删除后将从当前网盘列表移除。"
    }
}

struct FileBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        FileBrowserView(viewModel: FileBrowserViewModel(repository: FileRepository()))
    }
}

/// 移动文件时选择目标文件夹的 sheet 页面。
private struct MoveFileView: View {
    let file: FileItem
    let folders: [FileItem]
    let currentParentId: String?
    let onMove: (String?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button {
                    onMove(nil)
                    dismiss()
                } label: {
                    Label("根目录", systemImage: "externaldrive")
                }
                .disabled(currentParentId == nil)

                Section("选择目标文件夹") {
                    ForEach(validFolders) { folder in
                        Button {
                            onMove(folder.fileId)
                            dismiss()
                        } label: {
                            HStack {
                                Label(folder.name, systemImage: folder.type.systemImage)
                                Spacer()
                                if folder.fileId == currentParentId {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .disabled(folder.fileId == currentParentId)
                    }
                }
            }
            .navigationTitle("移动 \(file.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var validFolders: [FileItem] {
        // UI 层先过滤掉自己；更深层的“不能移动到子文件夹”由数据库层校验。
        folders.filter { $0.fileId != file.fileId }
    }
}

// sheet(item:) 要求 item 遵守 Identifiable，因此把 URL 包一层。
private struct ShareURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// 分享结果页。提供复制链接和系统分享入口。
private struct ShareLinkView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("分享链接已复制")
                    .font(.title2.bold())

                Text(url.absoluteString)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                ShareLink(item: url) {
                    Label("系统分享", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    UIPasteboard.general.string = url.absoluteString
                } label: {
                    Label("再次复制", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding(20)
            .navigationTitle("分享")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// 文件列表中的单行。
/// 左侧点击打开文件，右侧 ... 打开文件管理菜单。
private struct FileListItem<Actions: View>: View {
    let file: FileItem
    let open: () -> Void
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        HStack {
            Button(action: open) {
                FileRowView(file: file)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            if file.type == .folder || file.type == .txt || file.type == .video {
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            Menu {
                actions()
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("\(file.name) 更多操作")
        }
    }
}
