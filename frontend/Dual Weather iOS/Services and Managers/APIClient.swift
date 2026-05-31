import Foundation

enum APIError: LocalizedError {
    case badURL
    case unexpectedStatus(Int)

    var errorDescription: String? {
        switch self {
        case .badURL:                   return "Invalid request URL."
        case .unexpectedStatus(let code):  return "Server returned status \(code)."
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    var tokenProvider: (() async throws -> String)?

    private let session = URLSession.shared
    private let baseURL = AppConfig.apiBaseURL
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private init() {}

    func get<T: Decodable>(_ path: String) async throws -> T {
        let request = try await makeRequest(method: "GET", path: path)
        return try await perform(request)
    }

    func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        var request = try await makeRequest(method: "POST", path: path)
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await perform(request)
    }

    func delete(_ path: String) async throws {
        let request = try await makeRequest(method: "DELETE", path: path)
        let (_, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(code) else { throw APIError.unexpectedStatus(code) }
    }

    // MARK: - Private

    private func makeRequest(method: String, path: String) async throws -> URLRequest {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let token = try await tokenProvider?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(code) else { throw APIError.unexpectedStatus(code) }
        return try decoder.decode(T.self, from: data)
    }
}
