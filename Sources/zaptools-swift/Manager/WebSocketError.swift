//
//  WebSocketError.swift
//  zaptools-swift
//
//  Created by Brandon Santeliz on 3/27/25.
//

import Foundation

enum WebSocketError: Error {
    case encodingFailed
    case decodingFailed
    case messageSendFailed(Error)
    case receiveFailed(Error)
    case maxRetriesReached
}
