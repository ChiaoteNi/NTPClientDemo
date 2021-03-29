//
//  Data.swift
//  CorrectedTime
//
//  Created by 倪僑德 on 2021/3/28.
//

import Foundation

extension Data {

    /// Append byte (8 bits) into the data.
    mutating func append(byte data: Int8) {
        var data = data
        self.append(Data(bytes: &data, count: MemoryLayout<Int8>.size))
    }

    /// Append unsigned integer (32 bits; 4 bytes) into data.
    mutating func append(unsignedInteger data: UInt32, bigEndian: Bool = true) {
        var data = data.bigEndian
        self.append(Data(bytes: &data, count: MemoryLayout<UInt32>.size))
    }

    /// Append unsigned long (64 bits; 8 bytes) into data.
    mutating func append(unsignedLong data: UInt64) {
        var data = data.bigEndian
        self.append(Data(bytes: &data, count: MemoryLayout<UInt64>.size))
    }
}
