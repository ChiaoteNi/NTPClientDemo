//
//  SocketClient.swift
//  CorrectedTime
//
//  Created by 倪僑德 on 2021/2/11.
//

import Foundation
import Network

@available(iOS 12, *)
final class NWSocketClient {
    
    typealias ReceiveHandler = (_ data: Data) -> Void
    typealias ConnectHandler = (_ success: Bool) -> Void
    
    private let host: String
    private var connection: NWConnection?
    private var connectHandler: ConnectHandler?
    
    private var waitingSendPacket: (() -> Data)?
    
    private var receiveHandlers: [ReceiveHandler] = []
    private let receiveQueue: DispatchQueue = .init(
        label: "time.apple.com.NTPQueue",
        qos: .background,
        autoreleaseFrequency: .never
    )

    private(set) var isConnected: Bool = false {
        didSet {
            connectHandler?(isConnected)
            connectHandler = nil
            
            guard isConnected, let packet = waitingSendPacket else { return }
            connection?.send(content: packet(), completion: .idempotent)
            waitingSendPacket = nil
        }
    }
    
    init(host: String = "time.apple.com") {
        self.host = host
    }
    
    func start(then handler: ((_ success: Bool) -> Void)?) {
        if connection == nil || connection?.state == .cancelled {
            createConnection()
        }
        connection?.start(queue: receiveQueue)
        connectHandler = handler
    }
    
    func listen(then handler: @escaping ReceiveHandler) {
        receiveHandlers.append(handler)
    }
    
    func close() {
        connection?.cancel()
        connectHandler = nil
        connection = nil
    }
    
    func send(packet: @escaping () -> Data) {
        if isConnected {
            connection?.send(content: packet(), completion: .idempotent)
        } else {
            waitingSendPacket = packet
        }
    }
}

// MARK: - Private functions
extension NWSocketClient {
    
    private func createConnection() {
        let endpointHost: NWEndpoint.Host = .init(host)
        connection = .init(host: endpointHost, port: 123, using: .udp) // NTP protocol has noted we should use 123 port
        
        connection?.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .setup:                print("setup")
            case .preparing:            print("preparing")
            case .ready:
                self?.isConnected = true
                self?.startReceiveMessage()
            case .waiting(let error):   print("waiting, \(error)")
            case .cancelled:            print("cancelled")
            case .failed(let error):
                print("failed, \(error)")
                self?.isConnected = false
            @unknown default:           print("default")
            }
        }
    }
    
    private func startReceiveMessage() {
        connection?.receiveMessage { [weak self] data, context, isComplete, error in
            if let data = data {
                self?.receiveHandlers.forEach { $0(data) }
            } else {
                print(context)
                print(error)
            }
        }
    }
}
