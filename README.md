# SCServo Swift SDK

A Swift port of the Feetech SCServo library for controlling SC series servo motors. This library provides a complete Swift implementation that maintains compatibility with the original Python API while leveraging Swift's type safety and modern language features.

## Features

- **Complete Protocol Implementation**: Full support for SCServo communication protocol
- **Cross-Platform**: Works on macOS, iOS, and other Swift-supported platforms
- **Type Safety**: Leverages Swift's strong typing system for safer servo control
- **Modern API**: Clean, Swift-idiomatic interface with proper error handling
- **Sync Operations**: Support for synchronized read/write operations with multiple servos
- **Memory Safe**: No manual memory management required

## Installation

### Swift Package Manager

Add this package to your `Package.swift` file:

```swift
dependencies: [
    .package(path: "path/to/SCServoSwift")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL or local path
3. Select the package and add it to your target

## Quick Start

### Basic Ping Example

```swift
import SCServoSDK

// Initialize components
let portHandler = PortHandler(portName: "/dev/tty.usbserial-*")
let packetHandler = createPacketHandler(protocolEnd: 0)

do {
    // Open port and set baudrate
    try portHandler.openPort()
    try portHandler.setBaudRate(1000000)
    
    // Ping servo
    let (modelNumber, result, error) = packetHandler.ping(portHandler, servoId: 1)
    
    if result == .success && error.isEmpty {
        print("Servo found! Model number: \(modelNumber)")
    }
    
    portHandler.closePort()
} catch {
    print("Connection error: \(error)")
}
```

### Reading and Writing Data

```swift
// Write goal position
let (writeResult, writeError) = packetHandler.write2ByteTxRx(
    portHandler,
    servoId: 1,
    address: ControlTableAddress.goalPosition,
    data: 2048
)

// Read present position
let (position, readResult, readError) = packetHandler.read2ByteTxRx(
    portHandler,
    servoId: 1,
    address: ControlTableAddress.presentPosition
)
```

### Synchronized Operations

```swift
// Create sync write group
let syncWrite = GroupSyncWrite(
    port: portHandler,
    packetHandler: packetHandler,
    startAddress: ControlTableAddress.goalPosition,
    dataLength: 2
)

// Add multiple servos
syncWrite.addParam2Byte(servoId: 1, data: 1000)
syncWrite.addParam2Byte(servoId: 2, data: 2000)
syncWrite.addParam2Byte(servoId: 3, data: 3000)

// Execute synchronized write
let result = syncWrite.txPacket()
```

## API Documentation

### Core Components

#### PortHandler
Manages serial port communication with the servo controller.

```swift
class PortHandler: PortHandlerProtocol {
    init(portName: String)
    func openPort() throws
    func closePort()
    func setBaudRate(_ baudRate: UInt32) throws
    func readPort(_ length: Int) -> [UInt8]
    func writePort(_ data: [UInt8]) -> Int
}
```

#### PacketHandler
Handles SCServo protocol packet communication.

```swift
protocol PacketHandlerProtocol {
    func ping(_ port: PortHandlerProtocol, servoId: UInt8) -> (modelNumber: UInt16, result: CommResult, error: ProtocolError)
    func read1ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8) -> (data: UInt8, result: CommResult, error: ProtocolError)
    func write1ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: UInt8) -> (result: CommResult, error: ProtocolError)
    // ... more methods for 2-byte and 4-byte operations
}
```

#### GroupSyncWrite
Performs synchronized write operations to multiple servos.

```swift
class GroupSyncWrite {
    init(port: PortHandlerProtocol, packetHandler: PacketHandlerProtocol, startAddress: UInt8, dataLength: UInt8)
    func addParam(servoId: UInt8, data: [UInt8]) -> Bool
    func addParam2Byte(servoId: UInt8, data: UInt16) -> Bool
    func txPacket() -> CommResult
}
```

#### GroupSyncRead
Performs synchronized read operations from multiple servos.

```swift
class GroupSyncRead {
    init(port: PortHandlerProtocol, packetHandler: PacketHandlerProtocol, startAddress: UInt8, dataLength: UInt8)
    func addParam(servoId: UInt8) -> Bool
    func txRxPacket() -> CommResult
    func getData2Byte(servoId: UInt8, address: UInt8) -> UInt16
}
```

### Constants and Enumerations

#### Communication Results
```swift
enum CommResult: Int32 {
    case success = 0
    case portBusy = -1
    case txFail = -2
    case rxFail = -3
    case txError = -4
    case rxTimeout = -6
    case rxCorrupt = -7
    case notAvailable = -9
}
```

#### Control Table Addresses
```swift
struct ControlTableAddress {
    static let torqueEnable: UInt8 = 40
    static let goalPosition: UInt8 = 42
    static let goalSpeed: UInt8 = 46
    static let presentPosition: UInt8 = 56
}
```

#### Protocol Errors
```swift
struct ProtocolError: OptionSet {
    static let voltage = ProtocolError(rawValue: 1)
    static let angle = ProtocolError(rawValue: 2)
    static let overheat = ProtocolError(rawValue: 4)
    static let overload = ProtocolError(rawValue: 32)
}
```

## Examples

The library includes several example applications:

### 1. Ping Example
- Basic servo detection and communication test
- Demonstrates connection setup and basic ping operation
- File: `Examples/PingExample.swift`

### 2. Read/Write Example
- Individual servo position control
- Shows reading present position and setting goal position
- Includes motion monitoring and error handling
- File: `Examples/ReadWriteExample.swift`

### 3. Sync Read/Write Example
- Multi-servo coordinated control
- Demonstrates synchronized operations
- Shows how to control multiple servos simultaneously
- File: `Examples/SyncReadWriteExample.swift`

## Configuration

### Device Path Configuration
Update the device path to match your system:

```swift
// macOS
let deviceName = "/dev/tty.usbserial-*"

// Linux
let deviceName = "/dev/ttyUSB0"

// Check available ports
let availablePorts = PortHandler.availablePorts()
```

### Protocol Configuration
Set the correct protocol endianness for your servo series:

```swift
// For STS/SMS series (most common)
let packetHandler = createPacketHandler(protocolEnd: 0)

// For SCS series
let packetHandler = createPacketHandler(protocolEnd: 1)
```

### Baudrate Configuration
Common baudrates for SCServos:

```swift
try portHandler.setBaudRate(1000000)  // Most common
try portHandler.setBaudRate(115200)   // Alternative
try portHandler.setBaudRate(57600)    // Lower speed
```

## Error Handling

The library uses Swift's native error handling and result types:

```swift
do {
    try portHandler.openPort()
    try portHandler.setBaudRate(1000000)
    
    let (data, result, error) = packetHandler.read2ByteTxRx(portHandler, servoId: 1, address: 42)
    
    switch result {
    case .success:
        if error.isEmpty {
            print("Data: \(data)")
        } else {
            print("Protocol error: \(error.description)")
        }
    case .rxTimeout:
        print("Communication timeout - check connections")
    default:
        print("Communication error: \(result.description)")
    }
    
} catch SerialPortError.failedToOpen {
    print("Could not open serial port - check device path")
} catch SerialPortError.invalidBaudRate {
    print("Invalid baudrate specified")
} catch {
    print("Unexpected error: \(error)")
}
```

## Thread Safety

The library is designed for single-threaded use. If you need to access servos from multiple threads:

1. Use a single dedicated thread for all servo communication
2. Implement your own synchronization mechanisms
3. Create separate PortHandler instances for each thread (not recommended)

## Performance Considerations

- **Batch Operations**: Use sync read/write for multiple servos to reduce communication overhead
- **Timeout Settings**: Adjust packet timeouts based on your communication requirements
- **Baudrate**: Higher baudrates provide faster communication but may be less reliable over long distances

## Troubleshooting

### Common Issues

1. **Port Access Denied**
   ```bash
   # macOS/Linux: Add user to dialout group
   sudo usermod -a -G dialout $USER
   ```

2. **No Response from Servo**
   - Check power supply
   - Verify baudrate settings
   - Ensure correct servo ID
   - Check cable connections

3. **Communication Errors**
   - Reduce baudrate
   - Check for electromagnetic interference
   - Verify protocol endianness setting

### Debug Mode

Enable detailed logging in debug builds:

```swift
#if DEBUG
print("Communication result: \(result.description)")
print("Protocol error: \(error.description)")
#endif
```

## Compatibility

### Supported Servo Models
- **STS Series**: Smart Serial Servo (most common)
- **SMS Series**: Smart Serial Servo with magnetic encoder
- **SCS Series**: Smart Serial Servo with different protocol endianness

### Platform Requirements
- **macOS**: 10.15+
- **iOS**: 13.0+
- **Swift**: 5.7+

### Hardware Requirements
- USB to TTL serial converter (compatible with 3.3V or 5V logic)
- SCServo with serial communication capability
- Appropriate power supply for your servo model

## License

This Swift port maintains compatibility with the original Feetech library licensing terms. Please refer to the original library documentation for specific license information.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all examples still work
5. Submit a pull request

## Support

For issues specific to this Swift port, please open an issue on the repository. For general SCServo questions, refer to the original Feetech documentation.