import SwiftUI

/// 简易 txt 阅读器。
///
/// 核心能力：
/// - 读取 txt 内容。
/// - 根据屏幕尺寸估算分页。
/// - 左滑下一页，右滑上一页。
/// - 底部显示当前页码。
struct TextReaderView: View {
    let file: FileItem

    // 完整文本内容。
    @State private var content = ""

    // 分页后的文本数组。pages[0] 是第一页。
    @State private var pages: [String] = []

    // 当前页下标，从 0 开始。
    @State private var currentPage = 0

    private let contentService = TextContentService()

    // 阅读器字号。分页估算时会用它计算每行大概能容纳多少字。
    private let fontSize: CGFloat = 18

    var body: some View {
        // GeometryReader 用来获取当前页面尺寸。
        // 阅读器根据宽度和高度估算每页容量。
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    Text(currentText)
                        .font(.system(size: fontSize, weight: .regular, design: .serif))
                        .lineSpacing(8)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(20)
                }
                .scrollDisabled(true)
                // 阅读器采用“分页翻页”模式，所以禁用 ScrollView 自身滚动，
                // 改用左右拖拽手势切换页码。
                .gesture(
                    DragGesture(minimumDistance: 35)
                        .onEnded { value in
                            handleSwipe(width: value.translation.width)
                        }
                )

                Divider()

                HStack {
                    Button {
                        previousPage()
                    } label: {
                        Label("上一页", systemImage: "chevron.left")
                    }
                    .disabled(currentPage == 0)

                    Spacer()

                    Text("\(pageNumber) / \(max(pages.count, 1))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        nextPage()
                    } label: {
                        Label("下一页", systemImage: "chevron.right")
                    }
                    .disabled(currentPage >= pages.count - 1)
                }
                .font(.footnote)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(Color(.systemBackground))
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // 页面出现时读取文本并分页。
                loadAndPaginate(size: geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                // 屏幕尺寸变化时重新分页，避免旋转或布局变化后页码错乱。
                paginate(size: newSize)
            }
        }
    }

    private var currentText: String {
        guard pages.indices.contains(currentPage) else { return "暂无内容" }
        return pages[currentPage]
    }

    private var pageNumber: Int {
        pages.isEmpty ? 0 : currentPage + 1
    }

    /// 读取文本内容并执行分页。
    private func loadAndPaginate(size: CGSize) {
        content = contentService.loadContent(for: file)
        paginate(size: size)
    }

    /// 根据页面尺寸估算每页可容纳的字符数。
    ///
    /// 这不是专业排版算法，而是课程项目中足够稳定的简易实现：
    /// - 用宽度估算每行字符数。
    /// - 用高度估算每页行数。
    /// - 二者相乘得到每页容量。
    private func paginate(size: CGSize) {
        let usableWidth = max(size.width - 40, 220)
        let usableHeight = max(size.height - 92, 320)
        let charactersPerLine = max(Int(usableWidth / (fontSize * 0.62)), 12)
        let linesPerPage = max(Int(usableHeight / (fontSize + 10)), 8)
        let pageCapacity = max(Int(Double(charactersPerLine * linesPerPage) * 0.58), 160)

        let oldPage = currentPage
        pages = split(content, pageCapacity: pageCapacity)
        currentPage = min(oldPage, max(pages.count - 1, 0))
    }

    /// 将完整文本切成多页。
    /// 优先在空白或常见标点处分割，避免阅读体验太突兀。
    private func split(_ text: String, pageCapacity: Int) -> [String] {
        guard !text.isEmpty else { return [] }

        var result: [String] = []
        var page = ""

        for character in text {
            page.append(character)
            if page.count >= pageCapacity && (character.isWhitespace || "。！？；，,.!?;".contains(character)) {
                result.append(page.trimmingCharacters(in: .whitespacesAndNewlines))
                page = ""
            }
        }

        if !page.isEmpty {
            result.append(page.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return result.isEmpty ? [text] : result
    }

    /// 根据左右滑动方向切页。
    /// width < 0 表示向左滑，进入下一页；width > 0 表示向右滑，回到上一页。
    private func handleSwipe(width: CGFloat) {
        if width < -40 {
            nextPage()
        } else if width > 40 {
            previousPage()
        }
    }

    /// 进入下一页，已经是最后一页时不做处理。
    private func nextPage() {
        guard currentPage < pages.count - 1 else { return }
        currentPage += 1
    }

    /// 返回上一页，已经是第一页时不做处理。
    private func previousPage() {
        guard currentPage > 0 else { return }
        currentPage -= 1
    }
}

struct TextReaderView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            TextReaderView(
                file: FileItem(
                    fileId: "txt_readme",
                    name: "项目说明.txt",
                    size: 4096,
                    path: "/项目说明.txt",
                    type: .txt,
                    parentId: nil,
                    timestamp: Date(),
                    lastOpenedAt: nil,
                    savedAt: nil
                )
            )
        }
    }
}
