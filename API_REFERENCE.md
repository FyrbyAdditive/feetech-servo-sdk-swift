# SCServo Swift SDK - API Reference

## Overview

The SCServo Swift SDK provides a complete interface for controlling Feetech SCServo motors through serial communication. The API is designed to be type-safe, Swift-idiomatic, and compatible with the original Python library's functionality.

## Core Classes and Protocols

### PortHandler

The `PortHandler` class manages serial port communication.

#### Initialization

```swift
public init(portName: String)
```

Creates a new port handler for the specified device path.

**Parameters:**
- `portName`: The path to the serial device (e.g., "/dev/tty.usbserial-*")

#### Methods

##### Connection Management

```swift
public func openPort() throws
```
Opens the serial port connection.

**Throws:** `SerialPortError` if the port cannot be opened.

```swift
public func closePort()
```
Closes the serial port connection.

```swift
public func setBaudRate(_ baudRate: UInt32) throws
```
Sets the communication baud rate.

**Parameters:**
- `baudRate`: The desired baud rate (common values: 1000000, 115200, 57600)

**Throws:** `SerialPortError.invalidBaudRate` if the baud rate is not supported.

##### Data I/O

```swift
public func readPort(_ length: Int) -> [UInt8]
```
Reads data from the serial port.

**Parameters:**
- `length`: Number of bytes to read

**Returns:** Array of bytes read from the port.

```swift
public func writePort(_ data: [UInt8]) -> Int
```
Writes data to the serial port.

**Parameters:**
- `data`: Array of bytes to write

**Returns:** Number of bytes actually written.

##### Utility Methods

```swift
public func clearPort()
```
Flushes the serial port buffers.

```swift
public func getBytesAvailable() -> Int
```
Returns the number of bytes available for reading.

```swift
public static func availablePorts() -> [String]
```
Returns a list of available serial ports on the system.

#### Properties

```swift
public var isOpen: Bool { get }
```
Indicates whether the port is currently open.

```swift
public var baudRate: UInt32 { get }
```
The current baud rate setting.

```swift
public var portName: String { get }
```
The device path for this port.

---

### PacketHandler Protocol

The `PacketHandlerProtocol` defines the interface for SCServo protocol communication.

#### Factory Function

```swift
public func createPacketHandler(protocolEnd: Int) -> PacketHandlerProtocol
```

Creates a packet handler with the specified endianness.

**Parameters:**
- `protocolEnd`: Protocol endianness (0 for STS/SMS, 1 for SCS)

#### Communication Methods

##### Basic Operations

```swift
func ping(_ port: PortHandlerProtocol, servoId: UInt8) -> (modelNumber: UInt16, result: CommResult, error: ProtocolError)
```

Pings a servo to check connectivity and get model information.

**Parameters:**
- `port`: The port handler to use for communication
- `servoId`: The ID of the servo to ping (1-252)

**Returns:**
- `modelNumber`: The servo's model number (if successful)
- `result`: Communication result status
- `error`: Protocol-level error information

##### Read Operations

```swift
func read1ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8) -> (data: UInt8, result: CommResult, error: ProtocolError)
```

Reads a single byte from a servo register.

```swift
func read2ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8) -> (data: UInt16, result: CommResult, error: ProtocolError)
```

Reads a 16-bit word from servo registers.

```swift
func read4ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8) -> (data: UInt32, result: CommResult, error: ProtocolError)
```

Reads a 32-bit double word from servo registers.

##### Write Operations

```swift
func write1ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: UInt8) -> (result: CommResult, error: ProtocolError)
```

Writes a single byte to a servo register.

```swift
func write2ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: UInt16) -> (result: CommResult, error: ProtocolError)
```

Writes a 16-bit word to servo registers.

```swift
func write4ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: UInt32) -> (result: CommResult, error: ProtocolError)
```

Writes a 32-bit double word to servo registers.

---

### GroupSyncWrite

Performs synchronized write operations to multiple servos.

#### Initialization

```swift
public init(port: PortHandlerProtocol, packetHandler: PacketHandlerProtocol, startAddress: UInt8, dataLength: UInt8)
```

Creates a new sync write group.

**Parameters:**
- `port`: Port handler for communication
- `packetHandler`: Packet handler for protocol operations
- `startAddress`: Starting register address for write operations
- `dataLength`: Number of bytes to write per servo

#### Methods

##### Parameter Management

```swift
public func addParam(servoId: UInt8, data: [UInt8]) -> Bool
```

Adds a servo and its data to the sync write group.

**Parameters:**
- `servoId`: The servo ID to add
- `data`: The data bytes to write to this servo

**Returns:** `true` if successfully added, `false` if servo already exists or data is too long.

```swift
public func addParam2Byte(servoId: UInt8, data: UInt16) -> Bool
```

Convenience method to add a servo with 16-bit data.

```swift
public func addParam4Byte(servoId: UInt8, data: UInt32) -> Bool
```

Convenience method to add a servo with 32-bit data.

```swift
public func removeParam(servoId: UInt8)
```

Removes a servo from the sync write group.

```swift
public func changeParam(servoId: UInt8, data: [UInt8]) -> Bool
```

Changes the data for an existing servo in the group.

```swift
public func clearParam()
```

Removes all servos from the sync write group.

##### Execution

```swift
public func txPacket() -> CommResult
```

Executes the synchronized write operation for all servos in the group.

**Returns:** Communication result status.

#### Properties

```swift
public var servoCount: Int { get }
```
Number of servos in the group.

```swift
public var isEmpty: Bool { get }
```
Whether the group contains any servos.

---

### GroupSyncRead

Performs synchronized read operations from multiple servos.

#### Initialization

```swift
public init(port: PortHandlerProtocol, packetHandler: PacketHandlerProtocol, startAddress: UInt8, dataLength: UInt8)
```

Creates a new sync read group.

**Parameters:**
- `port`: Port handler for communication
- `packetHandler`: Packet handler for protocol operations
- `startAddress`: Starting register address for read operations
- `dataLength`: Number of bytes to read per servo

#### Methods

##### Parameter Management

```swift
public func addParam(servoId: UInt8) -> Bool
```

Adds a servo to the sync read group.

**Parameters:**
- `servoId`: The servo ID to add

**Returns:** `true` if successfully added, `false` if servo already exists.

```swift
public func removeParam(servoId: UInt8)
```

Removes a servo from the sync read group.

```swift
public func clearParam()
```

Removes all servos from the sync read group.

##### Execution

```swift
public func txRxPacket() -> CommResult
```

Executes the synchronized read operation for all servos in the group.

**Returns:** Communication result status.

##### Data Access

```swift
public func getData1Byte(servoId: UInt8, address: UInt8) -> UInt8
```

Gets 8-bit data from a specific servo and address.

```swift
public func getData2Byte(servoId: UInt8, address: UInt8) -> UInt16
```

Gets 16-bit data from a specific servo and address.

```swift
public func getData4Byte(servoId: UInt8, address: UInt8) -> UInt32
```

Gets 32-bit data from a specific servo and address.

```swift
public func isAvailable(servoId: UInt8, address: UInt8, dataLength: UInt8) -> Bool
```

Checks if data is available for a specific servo and address range.

---

## Enumerations and Structures

### CommResult

Communication result status codes.

```swift
public enum CommResult: Int32 {
    case success = 0        // Communication successful
    case portBusy = -1      // Port is busy
    case txFail = -2        // Transmission failed
    case rxFail = -3        // Reception failed
    case txError = -4       // Incorrect instruction packet
    case rxWaiting = -5     // Receiving status packet
    case rxTimeout = -6     // No status packet received
    case rxCorrupt = -7     // Incorrect status packet
    case notAvailable = -9  // Function not available
}
```

### ProtocolError

Protocol-level error flags.

```swift
public struct ProtocolError: OptionSet {
    static let voltage = ProtocolError(rawValue: 1)    // Input voltage error
    static let angle = ProtocolError(rawValue: 2)      // Angle sensor error
    static let overheat = ProtocolError(rawValue: 4)   // Overheat error
    static let overele = ProtocolError(rawValue: 8)    // Over-current error
    static let overload = ProtocolError(rawValue: 32)  // Overload error
}
```

### SerialPortError

Serial port related errors.

```swift
public enum SerialPortError: Error {
    case failedToOpen       // Could not open port
    case failedToSetBaudRate // Could not set baud rate
    case failedToRead       // Read operation failed
    case failedToWrite      // Write operation failed
    case invalidBaudRate    // Unsupported baud rate
    case portNotOpen        // Port not currently open
    case timeout            // Operation timed out
}
```

### ControlTableAddress

Common servo register addresses.

```swift
public struct ControlTableAddress {
    static let torqueEnable: UInt8 = 40      // Torque enable/disable
    static let goalAcc: UInt8 = 41           // Goal acceleration
    static let goalPosition: UInt8 = 42      // Goal position
    static let goalSpeed: UInt8 = 46         // Goal speed
    static let presentPosition: UInt8 = 56   // Current position
    static let modelNumber: UInt8 = 3        // Servo model number
}
```

### SCServoConstants

Protocol and communication constants.

```swift
public struct SCServoConstants {
    static let broadcastId: UInt8 = 0xFE     // Broadcast ID (254)
    static let maxId: UInt8 = 0xFC           // Maximum servo ID (252)
    static let defaultBaudrate: UInt32 = 1000000  // Default baud rate
    
    // Instruction constants
    static let instPing: UInt8 = 1           // Ping instruction
    static let instRead: UInt8 = 2           // Read instruction
    static let instWrite: UInt8 = 3          // Write instruction
    static let instSyncWrite: UInt8 = 131    // Sync write instruction
    static let instSyncRead: UInt8 = 130     // Sync read instruction
}
```

## Utility Functions

### SCServoUtils

Helper functions for data conversion and manipulation.

```swift
public struct SCServoUtils {
    static func makeWord(_ lowByte: UInt8, _ highByte: UInt8) -> UInt16
    static func makeDWord(_ lowWord: UInt16, _ highWord: UInt16) -> UInt32
    static func loWord(_ value: UInt32) -> UInt16
    static func hiWord(_ value: UInt32) -> UInt16
    static func loByte(_ value: UInt16) -> UInt8
    static func hiByte(_ value: UInt16) -> UInt8
    static func toHost(_ value: Int, _ bitPosition: Int) -> Int
    static func toServo(_ value: Int, _ bitPosition: Int) -> Int
}
```

## Usage Patterns

### Basic Communication Pattern

```swift
let portHandler = PortHandler(portName: "/dev/tty.usbserial-*")
let packetHandler = createPacketHandler(protocolEnd: 0)

do {
    try portHandler.openPort()
    try portHandler.setBaudRate(1000000)
    
    // Perform operations...
    
    portHandler.closePort()
} catch {
    print("Error: \(error)")
}
```

### Error Handling Pattern

```swift
let (data, result, error) = packetHandler.read2ByteTxRx(portHandler, servoId: 1, address: 42)

switch result {
case .success:
    if error.isEmpty {
        // Use data
        print("Position: \(data)")
    } else {
        // Handle protocol error
        print("Protocol error: \(error.description)")
    }
default:
    // Handle communication error
    print("Communication error: \(result.description)")
}
```

### Batch Operations Pattern

```swift
let syncWrite = GroupSyncWrite(port: portHandler, packetHandler: packetHandler, 
                              startAddress: ControlTableAddress.goalPosition, dataLength: 2)

// Add multiple servos
for (id, position) in servoPositions {
    syncWrite.addParam2Byte(servoId: id, data: position)
}

// Execute all at once
let result = syncWrite.txPacket()
```