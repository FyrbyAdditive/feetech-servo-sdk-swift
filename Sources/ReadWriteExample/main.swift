import Foundation
import SCServoSDK

// MARK: - Configuration

struct ReadWriteConfiguration {
    // Default settings
    static let servoId: UInt8 = 1
    static let baudRate: UInt32 = 1000000
    static let deviceName = "/dev/tty.usbserial-*" // Update this for your system
    static let protocolEnd = 0  // SCServo bit end (STS/SMS=0, SCS=1)
    
    // Motion parameters
    static let minimumPositionValue: UInt16 = 100
    static let maximumPositionValue: UInt16 = 4000
    static let movingStatusThreshold: UInt16 = 20
    static let movingSpeed: UInt16 = 0  // 0 means max speed
    static let movingAcc: UInt8 = 0     // 0 means max acceleration
}

// MARK: - Helper Functions

func setupConnection(portHandler: PortHandler, packetHandler: PacketHandlerProtocol) -> Bool {
    do {
        // Open port
        try portHandler.openPort()
        print("✓ Succeeded to open the port")
    } catch {
        print("✗ Failed to open the port: \(error)")
        return false
    }
    
    do {
        // Set port baudrate
        try portHandler.setBaudRate(ReadWriteConfiguration.baudRate)
        print("✓ Succeeded to change the baudrate to \(ReadWriteConfiguration.baudRate)")
    } catch {
        print("✗ Failed to change the baudrate: \(error)")
        portHandler.closePort()
        return false
    }
    
    return true
}

func initializeServo(portHandler: PortHandler, packetHandler: PacketHandlerProtocol) -> Bool {
    print("\n=== Initializing Servo Settings ===")
    
    // Set acceleration
    print("Setting acceleration to \(ReadWriteConfiguration.movingAcc)...")
    let (accResult, accError) = packetHandler.write1ByteTxRx(
        portHandler,
        servoId: ReadWriteConfiguration.servoId,
        address: ControlTableAddress.goalAcc,
        data: ReadWriteConfiguration.movingAcc
    )
    
    if accResult != .success {
        print("✗ Failed to write acceleration: \(accResult.description)")
        return false
    } else if !accError.isEmpty {
        print("✗ Protocol error writing acceleration: \(accError.description)")
        return false
    } else {
        print("✓ Acceleration set successfully")
    }
    
    // Set speed
    print("Setting speed to \(ReadWriteConfiguration.movingSpeed)...")
    let (speedResult, speedError) = packetHandler.write2ByteTxRx(
        portHandler,
        servoId: ReadWriteConfiguration.servoId,
        address: ControlTableAddress.goalSpeed,
        data: ReadWriteConfiguration.movingSpeed
    )
    
    if speedResult != .success {
        print("✗ Failed to write speed: \(speedResult.description)")
        return false
    } else if !speedError.isEmpty {
        print("✗ Protocol error writing speed: \(speedError.description)")
        return false
    } else {
        print("✓ Speed set successfully")
    }
    
    return true
}

func runReadWriteExample() {
    print("=== SCServo Swift Read/Write Example ===")
    
    // Initialize PortHandler
    let portHandler = PortHandler(portName: ReadWriteConfiguration.deviceName)
    
    // Initialize PacketHandler
    let packetHandler = createPacketHandler(protocolEnd: ReadWriteConfiguration.protocolEnd)
    
    // Setup connection
    guard setupConnection(portHandler: portHandler, packetHandler: packetHandler) else {
        return
    }
    
    // Initialize servo settings
    guard initializeServo(portHandler: portHandler, packetHandler: packetHandler) else {
        portHandler.closePort()
        return
    }
    
    // Goal positions array
    let goalPositions: [UInt16] = [
        ReadWriteConfiguration.minimumPositionValue,
        ReadWriteConfiguration.maximumPositionValue
    ]
    var index = 0
    
    print("\n=== Starting Motion Control ===")
    print("The servo will move between two positions.")
    print("Press 'q' and Enter to quit, or just Enter to continue...")
    
    // Main control loop
    while true {
        print("\nPress Enter to move servo (or 'q' to quit): ", terminator: "")
        if let input = readLine(), input.lowercased() == "q" {
            break
        }
        
        let goalPosition = goalPositions[index]
        
        // Write goal position
        print("Setting goal position to \(goalPosition)...")
        let (writeResult, writeError) = packetHandler.write2ByteTxRx(
            portHandler,
            servoId: ReadWriteConfiguration.servoId,
            address: ControlTableAddress.goalPosition,
            data: goalPosition
        )
        
        if writeResult != .success {
            print("✗ Failed to write goal position: \(writeResult.description)")
            continue
        } else if !writeError.isEmpty {
            print("✗ Protocol error writing goal position: \(writeError.description)")
            continue
        }
        
        // Monitor movement
        repeat {
            // Read present position and speed
            let (presentData, readResult, readError) = packetHandler.read4ByteTxRx(
                portHandler,
                servoId: ReadWriteConfiguration.servoId,
                address: ControlTableAddress.presentPosition
            )
            
            if readResult != .success {
                print("✗ Failed to read present position: \(readResult.description)")
                break
            } else if !readError.isEmpty {
                print("✗ Protocol error reading present position: \(readError.description)")
                break
            }
            
            let presentPosition = SCServoUtils.loWord(presentData)
            let presentSpeed = SCServoUtils.hiWord(presentData)
            let signedSpeed = SCServoUtils.toHost(Int(presentSpeed), 15)
            
            print("[ID:\(String(format: "%03d", ReadWriteConfiguration.servoId))] " +
                  "Goal:\(String(format: "%04d", goalPosition)) " +
                  "Present:\(String(format: "%04d", presentPosition)) " +
                  "Speed:\(String(format: "%04d", signedSpeed))")
            
            // Check if movement is complete
            let positionDifference = abs(Int(goalPosition) - Int(presentPosition))
            if positionDifference <= ReadWriteConfiguration.movingStatusThreshold {
                break
            }
            
            // Small delay to prevent flooding the communication
            usleep(100_000) // 100ms
            
        } while true
        
        // Switch to next position
        index = (index == 0) ? 1 : 0
    }
    
    // Disable torque before closing
    print("\nDisabling torque...")
    let (disableResult, disableError) = packetHandler.write1ByteTxRx(
        portHandler,
        servoId: ReadWriteConfiguration.servoId,
        address: ControlTableAddress.torqueEnable,
        data: 0
    )
    
    if disableResult != .success {
        print("✗ Failed to disable torque: \(disableResult.description)")
    } else if !disableError.isEmpty {
        print("✗ Protocol error disabling torque: \(disableError.description)")
    } else {
        print("✓ Torque disabled successfully")
    }
    
    // Close port
    portHandler.closePort()
    print("Port closed. Example completed.")
}

// MARK: - Entry Point

print("Starting SCServo Swift Read/Write Example...")
print("Make sure your servo is connected and powered on.")
print()

// List available ports
let availablePorts = PortHandler.availablePorts()
if !availablePorts.isEmpty {
    print("Available serial ports:")
    for port in availablePorts {
        print("  - \(port)")
    }
    print()
}

runReadWriteExample()