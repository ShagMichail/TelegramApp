import Foundation

public final class DivoAPIClient {
    public static let shared = DivoAPIClient()

    private let session: URLSession
    private let baseURL: URL

    private init() {
        self.baseURL = DivoConfig.baseURL
        self.session = URLSession.shared
    }

    public func request<T: Decodable>(
        path: String,
        method: String = "GET"
    ) async throws -> T {
        return try await request(path: path, method: method, body: Optional<EmptyBody>.none)
    }

    public func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: (some Encodable)?
    ) async throws -> T {
        let url = URL(string: baseURL.absoluteString + path)!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(DivoConfig.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(DivoConfig.appPlatform, forHTTPHeaderField: "app-platform")
        request.setValue(DivoConfig.appVersion, forHTTPHeaderField: "app-version")

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw DivoAPIError.unknown
        }

        guard (200...299).contains(http.statusCode) else {
            throw DivoAPIError.httpError(statusCode: http.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

public enum DivoAPIError: Error, LocalizedError {
    case httpError(statusCode: Int)
    case unknown

    public var errorDescription: String? {
        switch self {
        case .httpError(let code): return "HTTP \(code)"
        case .unknown: return "Unknown API error"
        }
    }
}

private struct EmptyBody: Encodable {}
