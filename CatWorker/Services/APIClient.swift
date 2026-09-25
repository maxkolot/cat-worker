import Foundation

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Talks to one server-mcp board API with its board key (board operations only, no shell).
struct APIClient {
    let server: ServerConfig

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private func request(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> Data {
        var base = server.url
        while base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: base + "/board/api" + path) else {
            throw APIError(message: "Неверный адрес сервера")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 20
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("Bearer \(server.key)", forHTTPHeaderField: "Authorization")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let message = json?["error"] as? String
            throw APIError(message: message ?? "Сервер ответил \(code)")
        }
        return data
    }

    func state() async throws -> BoardState {
        try Self.decoder.decode(BoardState.self, from: try await request("/state"))
    }

    func screens() async throws -> ScreensResponse {
        try Self.decoder.decode(ScreensResponse.self, from: try await request("/screens"))
    }

    func screenImage(_ id: String, width: Int) async throws -> Data {
        try await request("/screens/\(id).jpg?w=\(width)")
    }

    func setStatus(_ taskID: String, _ status: String) async throws {
        _ = try await request("/tasks/\(taskID)/status", method: "POST", body: ["status": status, "note": "из Cat Worker"])
    }

    func dispatch(_ taskID: String) async throws {
        _ = try await request("/tasks/\(taskID)/dispatch", method: "POST", body: ["by": "user"])
    }

    func addTask(roleID: String, spec: String) async throws {
        _ = try await request("/tasks", method: "POST", body: ["role_id": roleID, "spec": spec])
    }
}
