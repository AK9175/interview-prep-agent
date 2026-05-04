import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:               return "Invalid URL"
        case .networkError(let e):      return "Network error: \(e.localizedDescription)"
        case .decodingError(let e):     return "Decode error: \(e.localizedDescription)"
        case .serverError(let c, let m): return "Server \(c): \(m)"
        }
    }
}

final class APIService {

    static let shared = APIService()

    // Change this to your ngrok URL when testing on device
    // e.g. "https://abc123.ngrok-free.app"
    private let baseURL = "http://10.0.0.172:8000"

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        return URLSession(configuration: config)
    }()

    private init() {}

    // MARK: - Generic request

    private func post<Req: Encodable, Res: Decodable>(
        path: String,
        body: Req,
        as: Res.Type
    ) async throws -> Res {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let raw = String(data: data, encoding: .utf8) ?? "Unknown error"
            let msg: String
            if http.statusCode == 500 {
                msg = "The AI model is temporarily overloaded. Please try again in a moment."
            } else if http.statusCode == 503 {
                msg = "Service unavailable. Please try again shortly."
            } else {
                msg = raw
            }
            throw APIError.serverError(http.statusCode, msg)
        }

        do {
            return try JSONDecoder().decode(Res.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Memory

    func synthesizeMemory(_ req: MemorySynthesizeRequest) async throws -> MemorySynthesizeResponse {
        try await post(path: "/memory/synthesize", body: req, as: MemorySynthesizeResponse.self)
    }

    // MARK: - Interview

    func startInterview(_ req: StartInterviewRequest) async throws -> StartInterviewResponse {
        try await post(path: "/interview/start", body: req, as: StartInterviewResponse.self)
    }

    func submitAnswer(_ req: SubmitAnswerRequest) async throws -> SubmitAnswerResponse {
        try await post(path: "/interview/answer", body: req, as: SubmitAnswerResponse.self)
    }

    func summariseSession(_ req: SummariseRequest) async throws -> SummariseResponse {
        try await post(path: "/interview/summarise", body: req, as: SummariseResponse.self)
    }

    // MARK: - FAQ

    func askQuestion(_ req: AskQuestionRequest) async throws -> AskQuestionResponse {
        try await post(path: "/faq/ask", body: req, as: AskQuestionResponse.self)
    }

    func generateFlashcards(_ req: GenerateFAQRequest) async throws -> GenerateFAQResponse {
        try await post(path: "/faq/generate", body: req, as: GenerateFAQResponse.self)
    }
}
