//
//  WebSocketMessageEncoder.swift
//  zaptools-swift
//
//  Created by Brandon Santeliz on 3/27/25.
//

import Foundation

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
