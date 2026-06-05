import SwiftUI

struct FileRowView: View {
    let file: FileItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Image(systemName: file.type.systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(iconColor)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(file.type.displayName)
                    Text(file.formattedSize)
                    Text(file.formattedTimestamp)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private var iconColor: Color {
        switch file.type {
        case .folder: return .yellow
        case .video: return .purple
        case .txt: return .blue
        case .other: return .gray
        }
    }
}
