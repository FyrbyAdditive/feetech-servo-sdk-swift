import Foundation
import SCServoSDK

// MARK: - Configuration

struct SyncConfiguration {
    // Default settings
    static let servoIds: [UInt8] = [1, 2, 3] // Multiple servo IDs
    static let baudRate: UInt32 = 1000000
    static let deviceName = "/dev/tty.usbserial-*" // Update this for your system
    static let protocolEnd = 0  // SCServo bit end (STS/SMS=0, SCS=1)
    
    // Motion parameters
    static let positions: [UInt16] = [1000, 2000, 3000, 4000]
}

func runSyncExample() {
    print("=== SCServo Swift Sync Read/Write Example ===")
    print("Note: This example requires multiple servos with IDs: \(SyncConfiguration.servoIds)")
    print("Update SyncConfiguration.servoIds to match your setup.")
    print()
    
    // Initialize components
    let portHandler = PortHandler(portName: SyncConfiguration.deviceName)
    let packetHandler = createPacketHandler(protocolEnd: SyncConfiguration.protocolEnd)
    
    do {
        try portHandler.openPort()
        try portHandler.setBaudRate(SyncConfiguration.baudRate)
        print("✓ Port opened successfully")
    } catch {
        print("✗ Failed to setup port: \(error)")
        return
    }
    
    // Create sync write group
    let syncWrite = GroupSyncWrite(
        port: portHandler,
        packetHandler: packetHandler,
        startAddress: ControlTableAddress.goalPosition,
        dataLength: 2
    )
    
    // Add servos with different positions
    for (index, servoId) in SyncConfiguration.servoIds.enumerated() {
        let position = SyncConfiguration.positions[index % SyncConfiguration.positions.count]
        if syncWrite.addParam2Byte(servoId: servoId, data: position) {
            print("Added servo \(servoId) with position \(position)")
        } else {
            print("Failed to add servo \(servoId)")
        }
    }
    
    // Execute synchronized write
    print("\nExecuting synchronized write...")
    let result = syncWrite.txPacket()
    
    if result == .success {
        print("✓ Sync write executed successfully")
        print("All servos should now move to their target positions")
    } else {
        print("✗ Sync write failed: \(result.description)")
    }
    
    portHandler.closePort()
    print("Example completed.")
}

// MARK: - Entry Point

runSyncExample()