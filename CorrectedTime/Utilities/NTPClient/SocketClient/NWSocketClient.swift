//
//  SocketClient.swift
//  CorrectedTime
//
//  Created by 倪僑德 on 2021/2/11.
//

import Foundation
import Network

final class NWSocketClient {
    
    typealias ReceiveHandler = (_ data: Data) -> Void
    
    private let connection: NWConnection
    private var receiveHandlers: [ReceiveHandler] = []
    private let receiveQueue: DispatchQueue = .init(
        label: "time.apple.com.NTPQueue",
        qos: .background,
        autoreleaseFrequency: .never
    )
    
    init(host: String = "time.apple.com") {
        let endpointHost: NWEndpoint.Host = .init(host)
        connection = .init(host: endpointHost, port: 123, using: .udp) // NTP protocol has noted we should use 123 port
        
        connection.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .setup:                print("setup")
            case .preparing:            print("preparing")
            case .ready:                self?.startReceiveMessage()
            case .waiting(let error):   print("waiting, \(error)")
            case .cancelled:            print("cancelled")
            case .failed(let error):    print("failed, \(error)")
            @unknown default:           print("default")
            }
        }
    }
    
    func start() {
        connection.start(queue: receiveQueue)
    }
    
    func listen(then handler: @escaping ReceiveHandler) {
        receiveHandlers.append(handler)
    }
    
    func close() {
        // TODO: implement
    }
    
    func send(packet: @escaping () -> Data) {
        connection.send(content: packet(), completion: .idempotent)
    }
}

// MARK: - Private functions
extension NWSocketClient {
    
    private func startReceiveMessage() {
        connection.receiveMessage { [weak self] data, context, isComplete, error in
            if let data = data {
                self?.receiveHandlers.forEach { $0(data) }
            } else {
                print(context)
                print(error)
            }
        }
    }
}