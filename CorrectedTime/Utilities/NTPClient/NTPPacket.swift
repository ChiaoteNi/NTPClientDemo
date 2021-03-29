//
//  NTPPacket.swift
//  CorrectedTime
//
//  Created by 倪僑德 on 2021/2/13.
//

import Foundation

/// Delta between system and NTP time (1970 ~ 1900)
private let epochTimeInterval: Double = 2208988800

/*
      0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |LI | VN  |Mode |    Stratum    |     Poll      |   Precision   |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |                          Root Delay                           |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |                       Root Dispersion                         |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |                     Reference Identifier                      |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |                                                               |
     |                   Reference Timestamp (64)                    |
     |                                                               |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |                                                               |
     |                   Originate Timestamp (64)                    |
     |                                                               |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |                                                               |
     |                    Receive Timestamp (64)                     |
     |                                                               |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |                                                               |
     |                    Transmit Timestamp (64)                    |
     |                                                               |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |                 Key Identifier (optional) (32)                |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |                                                               |
     |                                                               |
     |                 Message Digest (optional) (128)               |
     |                                                               |
     |                                                               |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 */

struct NTPPacket {

    let leap: LeapIndicator
    let version: Int8
    let mode: Mode
    
    let stratum: Stratum
    let poll: Int8
    let precision: Int8
    let rootDelay: TimeInterval
    let rootDispersion: TimeInterval
    let clockSource: ClockSource
    
    let referenceTime: TimeInterval
    let originTime: TimeInterval
    let receiveTime: TimeInterval
    var transmitTime: TimeInterval = 0.0
    let destinationTime: TimeInterval
    
    init() {
        self.version = 3
        leap = .unsynchronized
        self.mode = .client
        stratum = .unspecified
        poll = 4
        precision = -6
        rootDelay = 1
        rootDispersion = 1
        clockSource = .referenceIdentifier(id: 0)
        referenceTime = -epochTimeInterval
        originTime = -epochTimeInterval
        receiveTime = -epochTimeInterval
        destinationTime = -1
    }
    
    init(data: Data, destinationTime: TimeInterval) throws {
        guard data.count >= 48 else {
            throw NTPError(
                code: 500,
                message: "packet format not correct, packet size should not be less than 48bytes, but the packet is \(data.count) bytes only"
            )
        }

        let configs: Int8 = getByte(from: data, at: 0) ?? 0
        leap       = LeapIndicator(rawValue: (configs >> 6)) ?? .noWarning
        version    = (configs >> 3) & 7
        mode       = Mode(rawValue: configs & 7) ?? .privateUse
        
        stratum    = Stratum(value: getByte(from: data, at: 1) ?? 0)
        poll       = getByte(from: data, at: 2) ?? 0
        precision  = getByte(from: data, at: 3) ?? 0
        
        rootDelay      = NTPPacket.intervalFromNTPFormat(getUnsignedInteger(from: data, at: 4) ?? 0)
        rootDispersion = NTPPacket.intervalFromNTPFormat(getUnsignedInteger(from: data, at: 8) ?? 0)
        clockSource    = ClockSource(
            stratum: stratum,
            sourceID: getUnsignedInteger(from: data, at: 12) ?? 0
        )
        
        referenceTime  = NTPPacket.dateFromNTPFormat(getUnsignedLong(from: data, at: 16) ?? 0)
        originTime     = NTPPacket.dateFromNTPFormat(getUnsignedLong(from: data, at: 24) ?? 0)
        receiveTime    = NTPPacket.dateFromNTPFormat(getUnsignedLong(from: data, at: 32) ?? 0)
        transmitTime   = NTPPacket.dateFromNTPFormat(getUnsignedLong(from: data, at: 40) ?? 0)
        
        self.destinationTime = destinationTime
    }

    mutating func prepareToSend(transmitTime: TimeInterval? = nil) -> Data {
        var rawDatas: [UInt32] = .init(repeating: 0, count: 12)
        let configs = CFSwapInt32(
            (3 << 30)
                | (4 << 27)
                | (3 << 24)
                | (0 << 16)
                | (4 << 8)
                | (0)
        )
        rawDatas[0] = configs

        var data = Data(bytes: rawDatas, count: 40) // 32bit * 10 / 8 = 48 byte
        data.append(unsignedLong: dateToNTPFormat(transmitTime ?? currentTime()))
        return data

    }
}

// MARK: - Private functions
extension NTPPacket {
    
    private func dateToNTPFormat(_ time: TimeInterval) -> UInt64 {
        let integer = UInt32(time + epochTimeInterval)
        let decimal = modf(time).1 * 4294967296.0 // 2 ^ 32
        return UInt64(integer) << 32 | UInt64(decimal)
    }

    private static func dateFromNTPFormat(_ time: UInt64) -> TimeInterval {
        let integer = Double(time >> 32)
        let decimal = Double(time & 0xffffffff) / 4294967296.0  // 100,000,000的16進制
        return integer - epochTimeInterval + decimal
    }

    private static func intervalFromNTPFormat(_ time: UInt32) -> TimeInterval {
        let integer = Double(time >> 16)
        let decimal = Double(time & 0xffff) / 65536
        return integer + decimal
    }
    
    private func currentTime() -> TimeInterval {
        var current = timeval()
        let systemTimeError = gettimeofday(&current, nil) != 0
        assert(!systemTimeError, "system clock error: sysstem time unavailable")
        return Double(current.tv_sec) + Double(current.tv_usec) / 1000000
    }
}

private func getByte(from data: Data, at index: Int) -> Int8? {
    return getValue(from: data, at: index, offset: 1, for: Int8.self)
}

private func getUnsignedInteger(from data: Data, at index: Int) -> UInt32? {
    guard let data: UInt32 = getValue(from: data,
                                      at: index,
                                      offset: 4,
                                      for: UInt32.self) else { return nil }
    return data.bigEndian
}

private func getUnsignedLong(from data: Data, at index: Int) -> UInt64? {
    guard let data: UInt64 = getValue(from: data,
                                      at: index,
                                      offset: 8,
                                      for: UInt64.self) else { return nil }
    return data.bigEndian
}

private func getValue<ValueType: FixedWidthInteger>(from data: Data,
                                                    at index: Int,
                                                    offset: Int,
                                                    for type: ValueType.Type) -> ValueType? {
    
    let data = data.subdata(in: index ..< index + offset)
        .withUnsafeBytes { rawPointer in
        rawPointer.bindMemory(to: type.self).baseAddress?.pointee
    }
    return data
}

struct NTPError: Error {
    let code: Int
    let message: String
}
