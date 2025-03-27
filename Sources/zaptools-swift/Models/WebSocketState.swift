//
//  WebSocketState.swift
//  zaptools-swift
//
//  Created by Brandon Santeliz on 3/27/25.
//

enum WebSocketState {
    case success(WebSocketMessage)
    case failure(Error)
}
