//
//  WebSocketMessage.swift
//  zaptools-swift
//
//  Created by Brandon Santeliz on 3/27/25.
//

import Foundation

struct WebSocketMessage: Codable {
    let eventName: String
    let headers: [String: String]
    let payload: String
}
