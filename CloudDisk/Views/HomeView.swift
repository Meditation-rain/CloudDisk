import SwiftUI

/// 网盘首页。
///
/// 展示用户信息、容量使用情况、最近转存和最近浏览。
/// 首页数据来自 HomeViewModel，HomeView 不直接访问 SQLite。
struct HomeView: View {
    @StateObject var viewModel: HomeViewModel

    // 项目中假设网盘总容量为 10GB。
    // 已用容量来自 SQLite 中所有非文件夹文件 size 的总和。
    private let totalCapacity: Int64 = 10 * 1024 * 1024 * 1024

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 42))
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CloudDisk 用户")
                                    .font(.headline)
                                Text("个人网盘示例账号")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ProgressView(value: usedRatio) {
                            Text("已使用 \(viewModel.stats?.formattedTotalSize ?? "--") / 10 GB")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // 最近转存：按 savedAt 倒序查询。
                    RecentSectionView(
                        title: "最近转存",
                        files: viewModel.recentSaved,
                        emptyText: "暂无最近转存"
                    )

                    // 最近浏览：按 lastOpenedAt 倒序查询。
                    RecentSectionView(
                        title: "最近浏览",
                        files: viewModel.recentOpened,
                        emptyText: "暂无最近浏览"
                    )

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("网盘")
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .task {
                // 首次进入首页时加载数据。
                await viewModel.load()
            }
            .onAppear {
                // 从文件页返回首页时刷新一次，确保最近浏览/最近转存及时更新。
                Task { await viewModel.load() }
            }
            .refreshable {
                await viewModel.load()
            }
        }
    }

    // 进度条比例 = 数据库统计出的已用容量 / 10GB。
    private var usedRatio: Double {
        guard let totalSize = viewModel.stats?.totalSize else { return 0 }
        return min(Double(totalSize) / Double(totalCapacity), 1)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(viewModel: HomeViewModel(repository: FileRepository()))
    }
}

/// 首页中“最近转存”和“最近浏览”的通用卡片。
private struct RecentSectionView: View {
    let title: String
    let files: [FileItem]
    let emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(spacing: 0) {
                if files.isEmpty {
                    Text(emptyText)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                } else {
                    ForEach(files) { file in
                        FileRowView(file: file)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)

                        if file.id != files.last?.id {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
