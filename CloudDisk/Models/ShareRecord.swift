import Foundation

struct ShareRecord: Identifiable, Codable, Hashable {
    let shareId: String
    let fileId: String
    let createdAt: Date

    var id: String { shareId }
}
