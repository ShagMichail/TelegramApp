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
            let body = String(data: data, encoding: .utf8) ?? ""
            print("❌ API Error [\(http.statusCode)] \(url.absoluteString): \(body)")
            throw DivoAPIError.httpError(statusCode: http.statusCode, body: body)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    public func upload<T: Decodable>(
        path: String,
        fileData: Data,
        fileName: String = "photo.jpg",
        mimeType: String = "image/jpeg"
    ) async throws -> T {
        let url = URL(string: baseURL.absoluteString + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(DivoConfig.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(DivoConfig.appPlatform, forHTTPHeaderField: "app-platform")
        request.setValue(DivoConfig.appVersion, forHTTPHeaderField: "app-version")
        
        var body = Data()
        
        let fieldName = "file"
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        let (data, response) = try await session.upload(for: request, from: body)
        
        guard let http = response as? HTTPURLResponse else {
            throw DivoAPIError.unknown
        }
        
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("❌ Upload Error [\(http.statusCode)]: \(body)")
            throw DivoAPIError.httpError(statusCode: http.statusCode, body: body)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

public enum DivoAPIError: Error, LocalizedError {
    case httpError(statusCode: Int, body: String = "")
    case unknown

    public var errorDescription: String? {
        switch self {
        case .httpError(let code, _): return "HTTP \(code)"
        case .unknown: return "Unknown API error"
        }
    }
}

private struct EmptyBody: Encodable {}
