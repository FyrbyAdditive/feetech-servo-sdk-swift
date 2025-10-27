import Foundation

// MARK: - Constants

public struct SCServoConstants {
    public static let broadcastId: UInt8 = 0xFE  // 254
    public static let maxId: UInt8 = 0xFC        // 252
    
    // Instructions for SCServo Protocol
    public static let instPing: UInt8 = 1
    public static let instRead: UInt8 = 2
    public static let instWrite: UInt8 = 3
    public static let instRegWrite: UInt8 = 4
    public static let instAction: UInt8 = 5
    public static let instSyncWrite: UInt8 = 131  // 0x83
    public static let instSyncRead: UInt8 = 130   // 0x82
    
    // Protocol Error bits
    public static let errbitVoltage: UInt8 = 1
    public static let errbitAngle: UInt8 = 2
    public static let errbitOverheat: UInt8 = 4
    public static let errbitOverele: UInt8 = 8
    public static let errbitOverload: UInt8 = 32
    
    // Packet structure positions
    public static let pktHeader0: Int = 0
    public static let pktHeader1: Int = 1
    public static let pktId: Int = 2
    public static let pktLength: Int = 3
    public static let pktInstruction: Int = 4
    public static let pktError: Int = 4
    public static let pktParameter0: Int = 5
    
    // Packet size limits
    public static let txPacketMaxLen: Int = 250
    public static let rxPacketMaxLen: Int = 250
    
    // Default port settings
    public static let defaultBaudrate: UInt32 = 1000000
    public static let latencyTimer: Double = 16.0
}

// MARK: - Communication Results

public enum CommResult: Int32 {
    case success = 0        // tx or rx packet communication success
    case portBusy = -1      // Port is busy (in use)
    case txFail = -2        // Failed transmit instruction packet
    case rxFail = -3        // Failed get status packet
    case txError = -4       // Incorrect instruction packet
    case rxWaiting = -5     // Now receiving status packet
    case rxTimeout = -6     // There is no status packet
    case rxCorrupt = -7     // Incorrect status packet
    case notAvailable = -9  // Function not available
    
    public var description: String {
        switch self {
        case .success:
            return "[TxRxResult] Communication success!"
        case .portBusy:
            return "[TxRxResult] Port is in use!"
        case .txFail:
            return "[TxRxResult] Failed transmit instruction packet!"
        case .rxFail:
            return "[TxRxResult] Failed get status packet from device!"
        case .txError:
            return "[TxRxResult] Incorrect instruction packet!"
        case .rxWaiting:
            return "[TxRxResult] Now receiving status packet!"
        case .rxTimeout:
            return "[TxRxResult] There is no status packet!"
        case .rxCorrupt:
            return "[TxRxResult] Incorrect status packet!"
        case .notAvailable:
            return "[TxRxResult] Protocol does not support this function!"
        }
    }
}

// MARK: - Protocol Error Types

public struct ProtocolError: OptionSet {
    public let rawValue: UInt8
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    public static let voltage = ProtocolError(rawValue: SCServoConstants.errbitVoltage)
    public static let angle = ProtocolError(rawValue: SCServoConstants.errbitAngle)
    public static let overheat = ProtocolError(rawValue: SCServoConstants.errbitOverheat)
    public static let overele = ProtocolError(rawValue: SCServoConstants.errbitOverele)
    public static let overload = ProtocolError(rawValue: SCServoConstants.errbitOverload)
    
    public var description: String {
        var descriptions: [String] = []
        
        if contains(.voltage) {
            descriptions.append("[RxPacketError] Input voltage error!")
        }
        if contains(.angle) {
            descriptions.append("[RxPacketError] Angle sen error!")
        }
        if contains(.overheat) {
            descriptions.append("[RxPacketError] Overheat error!")
        }
        if contains(.overele) {
            descriptions.append("[RxPacketError] OverEle error!")
        }
        if contains(.overload) {
            descriptions.append("[RxPacketError] Overload error!")
        }
        
        return descriptions.joined(separator: " ")
    }
}

// MARK: - Servo Endianness Configuration

public class SCServoEndian {
    private static var endianness: Int = 0  // 0 = little endian, 1 = big endian
    
    public static func getEndianness() -> Int {
        return endianness
    }
    
    public static func setEndianness(_ endian: Int) {
        endianness = endian
    }
}

// MARK: - Utility Functions

public struct SCServoUtils {
    
    /// Convert servo value to host representation
    public static func toHost(_ value: Int, _ bitPosition: Int) -> Int {
        if (value & (1 << bitPosition)) != 0 {
            return -(value & ~(1 << bitPosition))
        } else {
            return value
        }
    }
    
    /// Convert host value to servo representation
    public static func toServo(_ value: Int, _ bitPosition: Int) -> Int {
        if value < 0 {
            return (-value | (1 << bitPosition))
        } else {
            return value
        }
    }
    
    /// Make a 16-bit word from two bytes
    public static func makeWord(_ lowByte: UInt8, _ highByte: UInt8) -> UInt16 {
        if SCServoEndian.getEndianness() == 0 {
            return UInt16(lowByte) | (UInt16(highByte) << 8)
        } else {
            return UInt16(highByte) | (UInt16(lowByte) << 8)
        }
    }
    
    /// Make a 32-bit double word from two 16-bit words
    public static func makeDWord(_ lowWord: UInt16, _ highWord: UInt16) -> UInt32 {
        return UInt32(lowWord) | (UInt32(highWord) << 16)
    }
    
    /// Get low 16-bit word from a 32-bit value
    public static func loWord(_ value: UInt32) -> UInt16 {
        return UInt16(value & 0xFFFF)
    }
    
    /// Get high 16-bit word from a 32-bit value
    public static func hiWord(_ value: UInt32) -> UInt16 {
        return UInt16((value >> 16) & 0xFFFF)
    }
    
    /// Get low byte from a 16-bit word
    public static func loByte(_ value: UInt16) -> UInt8 {
        if SCServoEndian.getEndianness() == 0 {
            return UInt8(value & 0xFF)
        } else {
            return UInt8((value >> 8) & 0xFF)
        }
    }
    
    /// Get high byte from a 16-bit word
    public static func hiByte(_ value: UInt16) -> UInt8 {
        if SCServoEndian.getEndianness() == 0 {
            return UInt8((value >> 8) & 0xFF)
        } else {
            return UInt8(value & 0xFF)
        }
    }
}

// MARK: - Control Table Addresses

public struct ControlTableAddress {
    public static let modelNumber: UInt8 = 3
    public static let minAngleLimit: UInt8 = 9
    public static let maxAngleLimit: UInt8 = 11
    public static let torqueEnable: UInt8 = 40
    public static let goalAcc: UInt8 = 41
    public static let goalPosition: UInt8 = 42
    public static let goalSpeed: UInt8 = 46
    public static let presentPosition: UInt8 = 56
}