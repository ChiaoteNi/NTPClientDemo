import Foundation

extension Data {

    /// Appends the given byte (8 bits) into the receiver Data.
    ///
    /// - parameter data: The byte to be appended.
    mutating func append(byte data: Int8) {
        var data = data
        self.append(Data(bytes: &data, count: MemoryLayout<Int8>.size))
    }

    /// Appends the given unsigned integer (32 bits; 4 bytes) into the receiver Data.
    ///
    /// - parameter data: The unsigned integer to be appended.
    mutating func append(unsignedInteger data: UInt32, bigEndian: Bool = true) {
        var data = data.bigEndian
        self.append(Data(bytes: &data, count: MemoryLayout<UInt32>.size))
    }

    /// Appends the given unsigned long (64 bits; 8 bytes) into the receiver Data.
    ///
    /// - parameter data: The unsigned long to be appended.
    mutating func append(unsignedLong data: UInt64) {
        var data = data.bigEndian
        self.append(Data(bytes: &data, count: MemoryLayout<UInt64>.size))
    }
}
