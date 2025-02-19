//
//  WebSocketManager.swift
//  zaptools-swift
//
//  Created by Steven Santeliz on 18/2/25.
//

import Foundation

@available(iOS 13.0, *)
public final class WebSocketManager: NSObject {
    private let session: URLSession
    private let webSocket: URLSessionWebSocketTask?
    
    init(from url: String, session: URLSession = .shared) {
        self.session = session
        
        // TODO: - Add this config to configure method
        if let url = URL(string: url) {
            webSocket = session.webSocketTask(with: url)
        } else {
            webSocket = nil
        }
        
    }
}

@available(iOS 13.0, *)
extension WebSocketManager: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession,
                           webSocketTask: URLSessionWebSocketTask,
                           didOpenWithProtocol protocol: String?) {
        debugPrint("Did connect")
    }
    
    public func urlSession(_ session: URLSession,
                           webSocketTask: URLSessionWebSocketTask,
                           didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                           reason: Data?) {
        debugPrint("Did disconnect")
    }
}
