import Foundation

struct AISpeechRequest: Sendable {
  let text: String; let model: String; let voice: String
  var format = "mp3"; var speed = 1.0
}
struct AISpeechAudio: Sendable { let data: Data; let mimeType: String; let requestID: String? }
enum AIServiceError: LocalizedError { case invalidConfiguration(String), invalidRequest(String), unauthorized, insufficientBalance, rateLimited, server(Int, String), invalidResponse, transport(String) }
protocol AISpeechProvider: Sendable { func synthesize(_ request: AISpeechRequest) async throws -> AISpeechAudio }

actor AIService {
  private var provider: any AISpeechProvider
  init(provider: any AISpeechProvider) { self.provider = provider }
  func replaceProvider(_ next: any AISpeechProvider) { provider = next }
  func synthesize(_ request: AISpeechRequest) async throws -> AISpeechAudio {
    guard !request.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AIServiceError.invalidRequest("朗读内容为空") }
    return try await provider.synthesize(request)
  }
}

final class OpenAICompatibleSpeechProvider: AISpeechProvider, @unchecked Sendable {
  struct Configuration: Sendable { let endpoint: URL; let apiKey: String; var headers: [String: String] = [:] }
  private let configuration: Configuration
  init(configuration: Configuration) { self.configuration = configuration }
  func synthesize(_ request: AISpeechRequest) async throws -> AISpeechAudio {
    guard configuration.endpoint.scheme == "https", !configuration.apiKey.isEmpty else { throw AIServiceError.invalidConfiguration("请配置 HTTPS 接口和 API Key") }
    var urlRequest = URLRequest(url: configuration.endpoint); urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type"); urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
    configuration.headers.forEach { urlRequest.setValue($1, forHTTPHeaderField: $0) }
    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: ["input": request.text, "model": request.model, "voice": request.voice, "response_format": request.format, "speed": request.speed])
    do {
      let (data, response) = try await URLSession.shared.data(for: urlRequest)
      guard let http = response as? HTTPURLResponse else { throw AIServiceError.invalidResponse }
      switch http.statusCode { case 200...299: break; case 401, 403: throw AIServiceError.unauthorized; case 402: throw AIServiceError.insufficientBalance; case 429: throw AIServiceError.rateLimited; default: throw AIServiceError.server(http.statusCode, "AI 服务请求失败") }
      guard !data.isEmpty else { throw AIServiceError.invalidResponse }
      return AISpeechAudio(data: data, mimeType: http.value(forHTTPHeaderField: "Content-Type") ?? "audio/mpeg", requestID: http.value(forHTTPHeaderField: "X-Request-Id"))
    } catch let error as AIServiceError { throw error } catch { throw AIServiceError.transport(error.localizedDescription) }
  }
}
