import Foundation

struct NTPParsingError: Error {
    let code: Int?
    let message: String
}

enum LeapIndicator: Int8 {
    case noWarning
    case oneSecondMore
    case oneSecondLess
    case unsynchronized
}

/// The connection mode.
enum Mode: Int8 {
    case reserved
    case symmetricActive
    case symmetricPassive
    case client
    case server
    case broadcast
    case controlMessage
    case privateUse
}

/// 8-bit integer representing the stratum, with
/// values as following defined
///
///  | 0      | unspecified or invalid                              |
///
///  | 1      | primary server (e.g., equipped with a GPS receiver) |
///
///  | 2-15   | secondary server (via NTP)                          |
///
///  | 16     | unsynchronized                                      |
///
///  | 17-255 | reserved                                            |
enum Stratum: Int8 {
    case unspecified
    case primary
    case secondary
    case unsynchronized
    case invalid

    init(value: Int8) {
        switch value {
        case 0:         self = .unspecified
        case 1:         self = .primary
        case 2 ..< 15:  self = .secondary
        case 16:        self = .unsynchronized
        default:        self = .invalid
        }
    }
}

enum ClockSource {
    case referenceClock(id: UInt32)
    case debug(id: UInt32)
    case referenceIdentifier(id: UInt32)

    init(stratum: Stratum, sourceID: UInt32) {
        switch stratum {
        case .unspecified:          self = .debug(id: sourceID)
        case .primary:              self = .referenceClock(id: sourceID)
        case .secondary,
             .invalid,
             .unsynchronized:       self = .referenceIdentifier(id: sourceID)
        }
    }

    var id: UInt32 {
        switch self {
        case .referenceClock(let id):       return id
        case .debug(let id):                return id
        case .referenceIdentifier(let id):  return id
        }
    }
}
