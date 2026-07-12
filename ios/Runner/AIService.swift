import Foundation

/// 与具体厂商无关的语音合成请求。
struct AISpeechRequest: Sendable, Equatable {
  enum AudioFormat: String, Codable, Sendable {
    case mp3
    case wav
    case pcm
    case aac
  }

  let text: String
  let model: String
  let voice: String
  let format: AudioFormat
  let speed: Double

  init(
    text: String,
    model: String,
    voice: String,
    format: AudioFormat = .mp3,
    speed: Double = 1.0
  ) {
    self.text = text
    self.model = model
    self.voice = voice
    self.format = format
    self.speed = speed
  }
}

struct AISpeechAudio: Sendable {
  let data: Data
  let mimeType: String
  let requestID: String?
}

enum AIServiceError: LocalizedError, Equatable {
  case invalidConfiguration(String)
  case invalidRequest(String)
  case unauthorized
  case insufficientBalance
  case rateLimited
  case server(statusCode: Int, message: String)
  case invalidResponse
  case transport(String)

  var errorDescription: String? {
    switch self {
    case .invalidConfiguration(let message), .invalidRequest(let message):
      return message
    case .unauthorized:
      return "API Key 无效或已失效"
    case .insufficientBalance:
      return "AI 服务余额不足"
    case .rateLimited:
      return "请求过于频繁，请稍后重试"
    case .server(_, let message):
      return message
    case .invalidResponse:
      return "AI 服务返回了无法识别的响应"
    case .transport(let message):
      return "网络请求失败：\(message)"
    }
  }
}

protocol AISpeechProvider: Sendable {
  func synthesize(_ request: AISpeechRequest) async throws -> AISpeechAudio
}

/// AI 能力统一入口。阅读器只依赖此类型，不感知 OpenRouter、OpenAI 或自建服务。
actor AIService {
  private var speechProvider: any AISpeechProvider

  init(speechProvider: any AISpeechProvider) {
    self.speechProvider = speechProvider
  }

  func replaceSpeechProvider(_ provider: any AISpeechProvider) {
    speechProvider = provider
  }

  func synthesizeSpeech(_ request: AISpeechRequest) async throws -> AISpeechAudio {
    guard !request.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw AIServiceError.invalidRequest("朗读内容不能为空")
    }
    guard !request.model.isEmpty, !request.voice.isEmpty else {
      throw AIServiceError.invalidRequest("必须配置语音模型和音色")
    }
    guard (0.25...4.0).contains(request.speed) else {
      throw AIServiceError.invalidRequest("语速必须在 0.25 到 4.0 之间")
    }
    return try await speechProvider.synthesize(request)
  }
}

/// 兼容 OpenAI Audio Speech 请求格式的通用 Provider。
/// endpoint、Header、模型和音色均由设置注入，不包含任何厂商常量。
final class OpenAICompatibleSpeechProvider: AISpeechProvider, @unchecked Sendable {
  struct Configuration: Sendable, Equatable {
    let endpoint: URL
    let apiKey: String
    let authorizationHeader: String
    let extraHeaders: [String: String]
    let timeout: TimeInterval

    init(
      endpoint: URL,
      apiKey: String,
      authorizationHeader: String = "Authorization",
      extraHeaders: [String: String] = [:],
      timeout: TimeInterval = 60
    ) {
      self.endpoint = endpoint
      self.apiKey = apiKey
      self.authorizationHeader = authorizationHeader
      self.extraHeaders = extraHeaders
      self.timeout = timeout
    }
  }

  private struct Payload: Encodable {
    let input: String
    let model: String
    let voice: String
    let responseFormat: String
    let speed: Double

    enum CodingKeys: String, CodingKey {
      case input, model, voice, speed
      case responseFormat = "response_format"
    }
  }

  private let configuration: Configuration
  private let session: URLSession
  private let encoder = JSONEncoder()

  init(configuration: Configuration, session: URLSession = .shared) {
    self.configuration = configuration
    self.session = session
  }

  func synthesize(_ request: AISpeechRequest) async throws -> AISpeechAudio {
    guard configuration.endpoint.scheme == "https" else {
      throw AIServiceError.invalidConfiguration("AI 接口必须使用 HTTPS")
    }
    guard !configuration.apiKey.isEmpty else {
      throw AIServiceError.invalidConfiguration("请先填写 API Key")
    }

    var urlRequest = URLRequest(
      url: configuration.endpoint,
      cachePolicy: .reloadIgnoringLocalCacheData,
      timeoutInterval: configuration.timeout
    )
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue("Bearer \(configuration.apiKey)",
                        forHTTPHeaderField: configuration.authorizationHeader)
    configuration.extraHeaders.forEach { urlRequest.setValue($1, forHTTPHeaderField: $0) }
    urlRequest.httpBody = try encoder.encode(
      Payload(
        input: request.text,
        model: request.model,
        voice: request.voice,
        responseFormat: request.format.rawValue,
        speed: request.speed
      )
    )

    do {
      let (data, response) = try await session.data(for: urlRequest)
      guard let http = response as? HTTPURLResponse else {
        throw AIServiceError.invalidResponse
      }
      guard (200...299).contains(http.statusCode) else {
        throw mapError(statusCode: http.statusCode, data: data)
      }
      guard !data.isEmpty else { throw AIServiceError.invalidResponse }
      return AISpeechAudio(
        data: data,
        mimeType: http.value(forHTTPHeaderField: "Content-Type") ?? "audio/mpeg",
        requestID: http.value(forHTTPHeaderField: "X-Request-Id")
          ?? http.value(forHTTPHeaderField: "X-Generation-Id")
      )
    } catch let error as AIServiceError {
      throw error
    } catch {
      throw AIServiceError.transport(error.localizedDescription)
    }
  }

  private func mapError(statusCode: Int, data: Data) -> AIServiceError {
    switch statusCode {
    case 401, 403: return .unauthorized
    case 402: return .insufficientBalance
    case 429: return .rateLimited
    default:
      let message = Self.errorMessage(from: data) ?? "AI 服务错误（HTTP \(statusCode)）"
      return .server(statusCode: statusCode, message: message)
    }
  }

  private static func errorMessage(from data: Data) -> String? {
    guard
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    if let error = object["error"] as? [String: Any], let message = error["message"] as? String {
      return message
    }
    return object["message"] as? String
  }
}
