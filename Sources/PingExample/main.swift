import Foundation
import SCServoSDK

// MARK: - Configuration

struct ServoConfiguration {
    static let defaultServoId: UInt8 = 1
    static let baudRate: UInt32 = 1000000
    static let deviceName = "/dev/cu.usbmodem58FA0994571" // Update this for your system (use cu. not tty.)
    static let protocolEnd = 0  // SCServo bit end (STS/SMS=0, SCS=1)
}

// MARK: - Main Function

func runPingExample(servoId: UInt8) {
    print("=== SCServo Swift Ping Example ===")
    
    // List available ports first
    let availablePorts = PortHandler.availablePorts()
    if !availablePorts.isEmpty {
        print("Available serial ports:")
        for port in availablePorts {
            print("  - \(port)")
        }
        print()
        print("Update ServoConfiguration.deviceName to match your device.")
        print("Current setting: \(ServoConfiguration.deviceName)")
        print()
    } else {
        print("No serial ports found. Make sure your device is connected.")
        print()
    }
    
    // Initialize PortHandler
    let portHandler = PortHandler(portName: ServoConfiguration.deviceName)
    
    // Initialize PacketHandler
    let packetHandler = createPacketHandler(protocolEnd: ServoConfiguration.protocolEnd)
    
    do {
        // Open port
        try portHandler.openPort()
        print("✓ Succeeded to open the port: \(ServoConfiguration.deviceName)")
    } catch {
        print("✗ Failed to open the port: \(error)")
        print("\nTroubleshooting:")
        print("1. Check if the device is connected")
        print("2. Update the device path in the code")
        print("3. Make sure you have permission to access the serial port")
        return
    }
    
    do {
        // Set port baudrate
        try portHandler.setBaudRate(ServoConfiguration.baudRate)
        print("✓ Succeeded to change the baudrate to \(ServoConfiguration.baudRate)")
    } catch {
        print("✗ Failed to change the baudrate: \(error)")
        portHandler.closePort()
        return
    }
    
    // Try to ping the SCServo
    print("\nPinging servo with ID \(servoId)...")
    let (modelNumber, commResult, protocolError) = packetHandler.ping(portHandler, servoId: servoId)
    
    if commResult != .success {
        print("✗ Communication failed: \(commResult.description)")
        print("\nTroubleshooting:")
        print("1. Check servo power supply")
        print("2. Verify servo ID (current: \(servoId))")
        print("3. Check baudrate setting")
        print("4. Verify cable connections")
    } else if !protocolError.isEmpty {
        print("✗ Protocol error: \(protocolError.description)")
    } else {
        print("✓ [ID:\(String(format: "%03d", servoId))] ping Succeeded!")
        print("  Servo model number: \(modelNumber)")
    }
    
    // Close port
    portHandler.closePort()
    print("\nPort closed. Example completed.")
}

// MARK: - Entry Point

print("Starting SCServo Swift Ping Example...")
print("Make sure your servo is connected and powered on.")
print()

// Parse command line arguments
let arguments = CommandLine.arguments
var servoId: UInt8 = ServoConfiguration.defaultServoId

if arguments.count > 1 {
    if let id = UInt8(arguments[1]) {
        servoId = id
        print("Using servo ID from command line: \(servoId)")
    } else {
        print("Invalid servo ID argument. Using default: \(ServoConfiguration.defaultServoId)")
        print("Usage: swift run PingExample [servo_id]")
        print("Example: swift run PingExample 2")
    }
} else {
    print("No servo ID specified. Using default: \(ServoConfiguration.defaultServoId)")
    print("Usage: swift run PingExample [servo_id]")
}
print()

runPingExample(servoId: servoId)