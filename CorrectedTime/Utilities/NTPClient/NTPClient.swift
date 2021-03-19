//
//  NTPClient.swift
//  CorrectedTime
//
//  Created by 倪僑德 on 2021/1/26.
//

import Foundation

protocol NTPSocketClientSpec {

    init(host: String)
    
    func start()
    func listen(then handler: @escaping (_ data: Data) -> Void)
    func close()
    func send(packet: @escaping () -> Data)
}

extension NWSocketClient : NTPSocketClientSpec {}
extension CSocketClient : NTPSocketClientSpec {}

final class NTPClient {
    
    private let socketClinet: NTPSocketClientSpec
    private var correctedTime: CorrectedTime?
    
    private var lastBoottime: TimeInterval?
    
    init() {
        if #available(iOS 12, *) {
            socketClinet = NWSocketClient(host: "time.asia.apple.com")
        } else {
            socketClinet = CSocketClient(host: "time.asia.apple.com")
        }
    }
    
    func getTime() -> Date? {
        guard let correctedTime = correctedTime else { return nil }
        return correctedTime.currentTime
    }
    
    func listenNewCorrectedTime(then handler: @escaping (_ correcedTime: CorrectedTime) -> Void) {
        socketClinet.listen { [weak self] data in
            guard let self = self else { return }
            guard let packet = try? NTPPacket(data: data,
                                              destinationTime: CorrectedTime.currentTime()) else { return }
            
            // [ ( T2- T1 ) + ( T3 – T4 ) ] / 2
            let offset = ((packet.receiveTime - packet.originTime)
                            + (packet.transmitTime - packet.destinationTime)) / 2
            
            let newCorrectedTime: CorrectedTime = .init(
                offset: offset,
                originBoottime: self.lastBoottime ?? CorrectedTime.getCurrentBoottime()
            )
            
            self.correctedTime = newCorrectedTime
            handler(newCorrectedTime)
        }
    }
    
    func send() {
        socketClinet.start()
        socketClinet.send(packet: { [weak self] in
            var packet = NTPPacket()
            let data = packet.prepareToSend()
            self?.lastBoottime = CorrectedTime.getCurrentBoottime()
            return data
        })
    }
}
