import Foundation
import SCServoSDK

// MARK: - Constants

struct ServoConfiguration {
    static let servoId: UInt8 = 1
    static let baudRate: UInt32 = 1000000
    static let deviceName = "/dev/tty.usbserial-*" // Update this for your system
    static let protocolEnd = 0  // SCServo bit end (STS/SMS=0, SCS=1)
}

// MARK: - Ping Example

func runPingExample() {
    print("=== SCServo Swift Ping Example ===")
    
    // Initialize PortHandler
    let portHandler = PortHandler(portName: ServoConfiguration.deviceName)
    
    // Initialize PacketHandler
    let packetHandler = createPacketHandler(protocolEnd: ServoConfiguration.protocolEnd)
    
    do {
        // Open port
        try portHandler.openPort()
        print("✓ Succeeded to open the port")
    } catch {
        print("✗ Failed to open the port: \(error)")
        print("Press any key to terminate...")
        _ = readLine()
        return
    }
    
    do {
        // Set port baudrate
        try portHandler.setBaudRate(ServoConfiguration.baudRate)
        print("✓ Succeeded to change the baudrate to \(ServoConfiguration.baudRate)")
    } catch {
        print("✗ Failed to change the baudrate: \(error)")
        print("Press any key to terminate...")
        _ = readLine()
        portHandler.closePort()
        return
    }
    
    // Try to ping the SCServo
    print("\nPinging servo with ID \(ServoConfiguration.servoId)...")
    let (modelNumber, commResult, protocolError) = packetHandler.ping(portHandler, servoId: ServoConfiguration.servoId)
    
    if commResult != .success {
        print("✗ Communication failed: \(commResult.description)")
    } else if !protocolError.isEmpty {
        print("✗ Protocol error: \(protocolError.description)")
    } else {
        print("✓ [ID:\(String(format: "%03d", ServoConfiguration.servoId))] ping Succeeded. SCServo model number: \(modelNumber)")
    }
    
    // Close port
    portHandler.closePort()
    print("\nPort closed. Example completed.")
}

// MARK: - Utility Functions

func waitForUserInput(_ message: String = "Press Enter to continue...") {
    print(message)
    _ = readLine()
}

// MARK: - Main Execution

#if DEBUG
print("Starting SCServo Swift Ping Example...")
print("Make sure your servo is connected and powered on.")
print("Update the device path in ServoConfiguration.deviceName if needed.")
print()

// List available ports
let availablePorts = PortHandler.availablePorts()
if !availablePorts.isEmpty {
    print("Available serial ports:")
    for port in availablePorts {
        print("  - \(port)")
    }
    print()
} else {
    print("No serial ports found. Make sure your device is connected.")
    print()
}

waitForUserInput("Press Enter to start the ping example...")
runPingExample()
#endif