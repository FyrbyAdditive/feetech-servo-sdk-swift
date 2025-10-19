import Foundation
import SCServoSDK

// MARK: - Constants

struct SyncConfiguration {
    // Default settings
    static let servoIds: [UInt8] = [1, 2, 3] // Multiple servo IDs
    static let baudRate: UInt32 = 1000000
    static let deviceName = "/dev/tty.usbserial-*" // Update this for your system
    static let protocolEnd = 0  // SCServo bit end (STS/SMS=0, SCS=1)
    
    // Motion parameters
    static let minimumPositionValue: UInt16 = 100
    static let maximumPositionValue: UInt16 = 4000
    static let movingStatusThreshold: UInt16 = 20
    static let movingSpeed: UInt16 = 200
    static let movingAcc: UInt8 = 50
}

// MARK: - Sync Read Write Example

func runSyncReadWriteExample() {
    print("=== SCServo Swift Sync Read/Write Example ===")
    
    // Initialize PortHandler
    let portHandler = PortHandler(portName: SyncConfiguration.deviceName)
    
    // Initialize PacketHandler
    let packetHandler = createPacketHandler(protocolEnd: SyncConfiguration.protocolEnd)
    
    // Setup connection
    guard setupConnection(portHandler: portHandler, packetHandler: packetHandler) else {
        return
    }
    
    // Initialize servos
    guard initializeServos(portHandler: portHandler, packetHandler: packetHandler) else {
        portHandler.closePort()
        return
    }
    
    // Create sync write and sync read instances
    let syncWrite = GroupSyncWrite(
        port: portHandler,
        packetHandler: packetHandler,
        startAddress: ControlTableAddress.goalPosition,
        dataLength: 2  // 2 bytes for position
    )
    
    let syncRead = GroupSyncRead(
        port: portHandler,
        packetHandler: packetHandler,
        startAddress: ControlTableAddress.presentPosition,
        dataLength: 4  // 4 bytes for position + speed
    )
    
    // Add servos to sync groups
    for servoId in SyncConfiguration.servoIds {
        _ = syncRead.addParam(servoId: servoId)
    }
    
    // Goal positions for each servo
    var goalPositions: [[UInt16]] = [
        [SyncConfiguration.minimumPositionValue, SyncConfiguration.maximumPositionValue, 2000],  // Servo 1
        [SyncConfiguration.maximumPositionValue, SyncConfiguration.minimumPositionValue, 2000],  // Servo 2
        [2000, SyncConfiguration.minimumPositionValue, SyncConfiguration.maximumPositionValue]   // Servo 3
    ]
    
    var index = 0
    
    print("\n=== Starting Synchronized Motion Control ===")
    print("Multiple servos will move in coordination.")
    print("Press 'q' and Enter to quit, or just Enter to continue...")
    
    // Main control loop
    while true {
        print("\nPress any key to continue! (or press 'q' to quit)")
        if let input = readLine(), input.lowercased() == "q" {
            break
        }
        
        // Clear previous sync write parameters
        syncWrite.clearParam()
        
        // Add goal positions for all servos
        for (i, servoId) in SyncConfiguration.servoIds.enumerated() {
            let goalPosition = goalPositions[i][index % goalPositions[i].count]
            print("Setting servo \(servoId) goal position to \(goalPosition)")
            
            if !syncWrite.addParam2Byte(servoId: servoId, data: goalPosition) {
                print("✗ Failed to add parameters for servo \(servoId)")
                continue
            }
        }
        
        // Execute sync write
        let writeResult = syncWrite.txPacket()
        if writeResult != .success {
            print("✗ Sync write failed: \(writeResult.description)")
            continue
        }
        print("✓ Sync write command sent successfully")
        
        // Monitor movement for all servos
        repeat {
            // Execute sync read
            let readResult = syncRead.txRxPacket()
            if readResult != .success {
                print("✗ Sync read failed: \(readResult.description)")
                break
            }
            
            var allServosReachedGoal = true
            
            // Display status for all servos
            for (i, servoId) in SyncConfiguration.servoIds.enumerated() {
                let goalPosition = goalPositions[i][index % goalPositions[i].count]
                
                // Get present position and speed
                let presentData = syncRead.getData4Byte(servoId: servoId, address: ControlTableAddress.presentPosition)
                let presentPosition = SCServoUtils.loWord(presentData)
                let presentSpeed = SCServoUtils.hiWord(presentData)
                let signedSpeed = SCServoUtils.toHost(Int(presentSpeed), 15)
                
                print("[ID:\(String(format: "%03d", servoId))] " +
                      "Goal:\(String(format: "%04d", goalPosition)) " +
                      "Present:\(String(format: "%04d", presentPosition)) " +
                      "Speed:\(String(format: "%04d", signedSpeed))")
                
                // Check if this servo reached its goal
                let positionDifference = abs(Int(goalPosition) - Int(presentPosition))
                if positionDifference > SyncConfiguration.movingStatusThreshold {
                    allServosReachedGoal = false
                }
            }
            
            print("---")
            
            // Check if all servos reached their goals
            if allServosReachedGoal {
                print("✓ All servos reached their goal positions")
                break
            }
            
            // Small delay to prevent flooding the communication
            usleep(200_000) // 200ms
            
        } while true
        
        // Move to next set of positions
        index += 1
    }
    
    // Disable torque for all servos
    print("\nDisabling torque for all servos...")
    for servoId in SyncConfiguration.servoIds {
        let (disableResult, disableError) = packetHandler.write1ByteTxRx(
            portHandler,
            servoId: servoId,
            address: ControlTableAddress.torqueEnable,
            data: 0
        )
        
        if disableResult != .success {
            print("✗ Failed to disable torque for servo \(servoId): \(disableResult.description)")
        } else if !disableError.isEmpty {
            print("✗ Protocol error disabling torque for servo \(servoId): \(disableError.description)")
        } else {
            print("✓ Torque disabled for servo \(servoId)")
        }
    }
    
    // Close port
    portHandler.closePort()
    print("\nPort closed. Example completed.")
}

// MARK: - Helper Functions

func setupConnection(portHandler: PortHandler, packetHandler: PacketHandlerProtocol) -> Bool {
    do {
        // Open port
        try portHandler.openPort()
        print("✓ Succeeded to open the port")
    } catch {
        print("✗ Failed to open the port: \(error)")
        print("Press any key to terminate...")
        _ = readLine()
        return false
    }
    
    do {
        // Set port baudrate
        try portHandler.setBaudRate(SyncConfiguration.baudRate)
        print("✓ Succeeded to change the baudrate to \(SyncConfiguration.baudRate)")
    } catch {
        print("✗ Failed to change the baudrate: \(error)")
        print("Press any key to terminate...")
        _ = readLine()
        portHandler.closePort()
        return false
    }
    
    return true
}

func initializeServos(portHandler: PortHandler, packetHandler: PacketHandlerProtocol) -> Bool {
    print("\n=== Initializing Servo Settings ===")
    
    for servoId in SyncConfiguration.servoIds {
        print("Initializing servo \(servoId)...")
        
        // Ping servo to check connection
        let (modelNumber, pingResult, pingError) = packetHandler.ping(portHandler, servoId: servoId)
        if pingResult != .success {
            print("✗ Failed to ping servo \(servoId): \(pingResult.description)")
            return false
        } else if !pingError.isEmpty {
            print("✗ Protocol error pinging servo \(servoId): \(pingError.description)")
            return false
        } else {
            print("✓ Servo \(servoId) found (Model: \(modelNumber))")
        }
        
        // Set acceleration
        let (accResult, accError) = packetHandler.write1ByteTxRx(
            portHandler,
            servoId: servoId,
            address: ControlTableAddress.goalAcc,
            data: SyncConfiguration.movingAcc
        )
        
        if accResult != .success {
            print("✗ Failed to write acceleration for servo \(servoId): \(accResult.description)")
            return false
        } else if !accError.isEmpty {
            print("✗ Protocol error writing acceleration for servo \(servoId): \(accError.description)")
            return false
        }
        
        // Set speed
        let (speedResult, speedError) = packetHandler.write2ByteTxRx(
            portHandler,
            servoId: servoId,
            address: ControlTableAddress.goalSpeed,
            data: SyncConfiguration.movingSpeed
        )
        
        if speedResult != .success {
            print("✗ Failed to write speed for servo \(servoId): \(speedResult.description)")
            return false
        } else if !speedError.isEmpty {
            print("✗ Protocol error writing speed for servo \(servoId): \(speedError.description)")
            return false
        }
        
        // Enable torque
        let (torqueResult, torqueError) = packetHandler.write1ByteTxRx(
            portHandler,
            servoId: servoId,
            address: ControlTableAddress.torqueEnable,
            data: 1
        )
        
        if torqueResult != .success {
            print("✗ Failed to enable torque for servo \(servoId): \(torqueResult.description)")
            return false
        } else if !torqueError.isEmpty {
            print("✗ Protocol error enabling torque for servo \(servoId): \(torqueError.description)")
            return false
        }
        
        print("✓ Servo \(servoId) initialized successfully")
    }
    
    return true
}

func waitForUserInput(_ message: String = "Press Enter to continue...") {
    print(message)
    _ = readLine()
}

// MARK: - Main Execution

#if DEBUG
print("Starting SCServo Swift Sync Read/Write Example...")
print("Make sure your servos are connected and powered on.")
print("Update the device path in SyncConfiguration.deviceName if needed.")
print("Update the servo IDs in SyncConfiguration.servoIds to match your setup.")
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

waitForUserInput("Press Enter to start the sync read/write example...")
runSyncReadWriteExample()
#endif