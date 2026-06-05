import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var recentOpened: [FileItem] = []
    @Published private(set) var recentSaved: [FileItem] = []
    @Published private(set) var stats: DatabaseStats?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: FileRepository

    init(repository: FileRepository) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            try await repository.prepareInitialData()
            recentOpened = try await repository.recentOpened()
            recentSaved = try await repository.recentSaved()
            stats = try await repository.databaseStats()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
