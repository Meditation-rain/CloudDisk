import Foundation

struct MockNetworkService {
    func fetchInitialFiles() async throws -> [FileItem] {
        try await Task.sleep(nanoseconds: 250_000_000)

        guard let url = Bundle.main.url(forResource: "mock_files", withExtension: "json") else {
            throw MockNetworkError.missingResource
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([FileItem].self, from: data)
    }
}

enum MockNetworkError: LocalizedError {
    case missingResource

    var errorDescription: String? {
        switch self {
        case .missingResource:
            return "找不到 mock_files.json"
        }
    }
}
