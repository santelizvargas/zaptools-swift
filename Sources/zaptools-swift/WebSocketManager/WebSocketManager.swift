import SwiftUI
import Combine

// MARK: - WebSocketState Enum
enum WebSocketState {
    case success(WebSocketMessage)
    case failure(Error)
}

// MARK: - WebSocketError Enum
enum WebSocketError: Error {
    case encodingFailed
    case decodingFailed
    case messageSendFailed(Error)
    case receiveFailed(Error)
    case maxRetriesReached
}

// MARK: - WebSocketMessage Model
struct WebSocketMessage: Codable {
    let eventName: String
    let headers: [String: String]
    let payload: String
}

protocol WebSocketMessageEncoding {
    func encode(_ message: WebSocketMessage) throws -> String
    func decode(_ jsonString: String) throws -> WebSocketMessage
}

// MARK: - WebSocketMessageEncoder
final class WebSocketMessageEncoder: WebSocketMessageEncoding {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    init(
        encoder: JSONEncoder = .init(),
        decoder: JSONDecoder = .init()
    ) {
        self.encoder = encoder
        self.decoder = decoder
    }
    
    func encode(_ message: WebSocketMessage) throws -> String {
        let jsonData = try encoder.encode(message)
        
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw WebSocketError.encodingFailed
        }
        return jsonString
    }
    
    func decode(_ jsonString: String) throws -> WebSocketMessage {
        guard let data = jsonString.data(using: .utf8) else {
            throw WebSocketError.decodingFailed
        }
        return try decoder.decode(WebSocketMessage.self, from: data)
    }
}

// MARK: - WebSocketManager
@available(iOS 15.0, *)
actor WebSocketManager: NSObject {
    private var webSocket: URLSessionWebSocketTask?
    private let session: URLSession
    private let url: String
    private let messageEncoder: WebSocketMessageEncoding
    private var retryCount = 0
    private let maxRetries = 5
    private let baseRetryDelay: TimeInterval = 2.0
    private var isConnecting = false
    
    private let messagesSubject = PassthroughSubject<WebSocketState, Never>()
    
    var messagesPublisher: AnyPublisher<WebSocketState, Never> {
        messagesSubject.eraseToAnyPublisher()
    }
    
    init(
        url: String,
        session: URLSession? = nil,
        messageEncoder: WebSocketMessageEncoding = WebSocketMessageEncoder()
    ) {
        self.url = url
        self.messageEncoder = messageEncoder
        
        self.session = session ?? URLSession(
            configuration: .default,
            delegate: nil,
            delegateQueue: nil
        )
        
        super.init()
    }
    
    func connect() {
        guard !isConnecting,
              let validURL = URL(string: url) else { return }
        isConnecting = true
        webSocket = session.webSocketTask(with: validURL)
        webSocket?.resume()
        listenForMessages()
    }
    
    func disconnect() {
        webSocket?.cancel(
            with: .goingAway,
            reason: "Manual Disconnect".data(using: .utf8)
        )
        isConnecting = false
    }
    
    func sendMessage(_ message: String) async throws {
        let messageData = WebSocketMessage(
            eventName: "new-message",
            headers: [:],
            payload: message
        )
        do {
            let jsonData = try messageEncoder.encode(messageData)
            try await sendWebSocketMessage(jsonData)
        } catch {
            throw WebSocketError.encodingFailed
        }
    }
    
    @discardableResult
    private func sendWebSocketMessage(_ jsonData: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            webSocket?.send(.string(jsonData)) { error in
                if let error {
                    continuation.resume(throwing: WebSocketError.messageSendFailed(error))
                } else {
                    continuation.resume(returning: true)
                }
            }
        }
    }
    
    private func listenForMessages() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }
            Task {
                switch result {
                    case .success(let message):
                        await self.processReceivedMessage(message)
                        await self.setRetryCount(.zero)
                    case .failure(let error):
                        await self.handleError(error)
                }
                await self.listenForMessages()
            }
        }
    }
    
    private func processReceivedMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
            case .string(let receivedText):
                do {
                    let decodedMessage = try messageEncoder.decode(receivedText)
                    messagesSubject.send(.success(decodedMessage))
                } catch {
                    messagesSubject.send(.failure(WebSocketError.decodingFailed))
                }
            case .data(let receivedData):
                print("📩 Received binary data: \(receivedData.count) bytes")
            @unknown default:
                print("⚠️ Received unknown WebSocket message type")
        }
    }
    
    private func handleError(_ error: Error) async {
        messagesSubject.send(.failure(WebSocketError.receiveFailed(error)))
        await setIsConnecting(false)
        await retryConnection()
    }
    
    private func retryConnection() async {
        guard retryCount < maxRetries else {
            messagesSubject.send(.failure(WebSocketError.maxRetriesReached))
            return
        }
        let delay = baseRetryDelay * pow(2.0, Double(retryCount))
        retryCount += 1
        print("🔄 Retrying WebSocket connection in \(delay) seconds... (Attempt \(retryCount))")
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        await setIsConnecting(false)
        connect()
    }
    
    private func setRetryCount(_ count: Int) async {
        retryCount = count
    }
    
    private func setIsConnecting(_ value: Bool) async {
        isConnecting = value
    }
}
