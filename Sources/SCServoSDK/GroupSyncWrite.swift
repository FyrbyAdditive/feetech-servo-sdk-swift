import Foundation

// MARK: - Group Sync Write Class

public class GroupSyncWrite {
    
    // MARK: - Properties
    
    private let port: PortHandlerProtocol
    private let packetHandler: PacketHandlerProtocol
    private let startAddress: UInt8
    private let dataLength: UInt8
    
    private var isParamChanged: Bool = false
    private var param: [UInt8] = []
    private var dataDict: [UInt8: [UInt8]] = [:]
    
    // MARK: - Initialization
    
    public init(port: PortHandlerProtocol, packetHandler: PacketHandlerProtocol, startAddress: UInt8, dataLength: UInt8) {
        self.port = port
        self.packetHandler = packetHandler
        self.startAddress = startAddress
        self.dataLength = dataLength
        clearParam()
    }
    
    // MARK: - Public Methods
    
    /// Add a servo ID and its data to the sync write group
    /// - Parameters:
    ///   - servoId: The ID of the servo to add
    ///   - data: The data to write to the servo
    /// - Returns: true if successfully added, false if servo ID already exists or data is too long
    public func addParam(servoId: UInt8, data: [UInt8]) -> Bool {
        if dataDict[servoId] != nil {
            return false  // servo ID already exists
        }
        
        guard data.count <= dataLength else {
            return false  // input data is longer than set data length
        }
        
        dataDict[servoId] = data
        isParamChanged = true
        return true
    }
    
    /// Remove a servo ID from the sync write group
    /// - Parameter servoId: The ID of the servo to remove
    public func removeParam(servoId: UInt8) {
        dataDict.removeValue(forKey: servoId)
        isParamChanged = true
    }
    
    /// Change the data for an existing servo ID
    /// - Parameters:
    ///   - servoId: The ID of the servo to modify
    ///   - data: The new data to write to the servo
    /// - Returns: true if successfully changed, false if servo ID doesn't exist or data is too long
    public func changeParam(servoId: UInt8, data: [UInt8]) -> Bool {
        guard dataDict[servoId] != nil else {
            return false  // servo ID doesn't exist
        }
        
        guard data.count <= dataLength else {
            return false  // input data is longer than set data length
        }
        
        dataDict[servoId] = data
        isParamChanged = true
        return true
    }
    
    /// Clear all parameters from the sync write group
    public func clearParam() {
        dataDict.removeAll()
        isParamChanged = true
    }
    
    /// Transmit the sync write packet
    /// - Returns: Communication result
    public func txPacket() -> CommResult {
        guard !dataDict.isEmpty else {
            return .notAvailable
        }
        
        if isParamChanged || param.isEmpty {
            makeParam()
        }
        
        return packetHandler.syncWriteTxOnly(port, startAddress: startAddress, dataLength: dataLength, param: param)
    }
    
    // MARK: - Convenience Methods for Adding Parameters
    
    /// Add a servo with 1-byte data
    /// - Parameters:
    ///   - servoId: The servo ID
    ///   - data: The 1-byte data value
    /// - Returns: true if successfully added
    public func addParam1Byte(servoId: UInt8, data: UInt8) -> Bool {
        return addParam(servoId: servoId, data: [data])
    }
    
    /// Add a servo with 2-byte data
    /// - Parameters:
    ///   - servoId: The servo ID
    ///   - data: The 2-byte data value
    /// - Returns: true if successfully added
    public func addParam2Byte(servoId: UInt8, data: UInt16) -> Bool {
        let dataBytes = [SCServoUtils.loByte(data), SCServoUtils.hiByte(data)]
        return addParam(servoId: servoId, data: dataBytes)
    }
    
    /// Add a servo with 4-byte data
    /// - Parameters:
    ///   - servoId: The servo ID
    ///   - data: The 4-byte data value
    /// - Returns: true if successfully added
    public func addParam4Byte(servoId: UInt8, data: UInt32) -> Bool {
        let loWord = SCServoUtils.loWord(data)
        let hiWord = SCServoUtils.hiWord(data)
        let dataBytes = [
            SCServoUtils.loByte(loWord),
            SCServoUtils.hiByte(loWord),
            SCServoUtils.loByte(hiWord),
            SCServoUtils.hiByte(hiWord)
        ]
        return addParam(servoId: servoId, data: dataBytes)
    }
    
    // MARK: - Convenience Methods for Changing Parameters
    
    /// Change a servo's 1-byte data
    /// - Parameters:
    ///   - servoId: The servo ID
    ///   - data: The new 1-byte data value
    /// - Returns: true if successfully changed
    public func changeParam1Byte(servoId: UInt8, data: UInt8) -> Bool {
        return changeParam(servoId: servoId, data: [data])
    }
    
    /// Change a servo's 2-byte data
    /// - Parameters:
    ///   - servoId: The servo ID
    ///   - data: The new 2-byte data value
    /// - Returns: true if successfully changed
    public func changeParam2Byte(servoId: UInt8, data: UInt16) -> Bool {
        let dataBytes = [SCServoUtils.loByte(data), SCServoUtils.hiByte(data)]
        return changeParam(servoId: servoId, data: dataBytes)
    }
    
    /// Change a servo's 4-byte data
    /// - Parameters:
    ///   - servoId: The servo ID
    ///   - data: The new 4-byte data value
    /// - Returns: true if successfully changed
    public func changeParam4Byte(servoId: UInt8, data: UInt32) -> Bool {
        let loWord = SCServoUtils.loWord(data)
        let hiWord = SCServoUtils.hiWord(data)
        let dataBytes = [
            SCServoUtils.loByte(loWord),
            SCServoUtils.hiByte(loWord),
            SCServoUtils.loByte(hiWord),
            SCServoUtils.hiByte(hiWord)
        ]
        return changeParam(servoId: servoId, data: dataBytes)
    }
    
    // MARK: - Query Methods
    
    /// Get all servo IDs in the group
    /// - Returns: Array of servo IDs
    public func getServoIds() -> [UInt8] {
        return Array(dataDict.keys).sorted()
    }
    
    /// Get the data for a specific servo ID
    /// - Parameter servoId: The servo ID
    /// - Returns: The data array for the servo, or nil if not found
    public func getData(for servoId: UInt8) -> [UInt8]? {
        return dataDict[servoId]
    }
    
    /// Check if a servo ID exists in the group
    /// - Parameter servoId: The servo ID to check
    /// - Returns: true if the servo exists in the group
    public func hasServo(_ servoId: UInt8) -> Bool {
        return dataDict[servoId] != nil
    }
    
    /// Get the number of servos in the group
    /// - Returns: The count of servos
    public var servoCount: Int {
        return dataDict.count
    }
    
    /// Check if the group is empty
    /// - Returns: true if no servos are in the group
    public var isEmpty: Bool {
        return dataDict.isEmpty
    }
    
    // MARK: - Private Methods
    
    private func makeParam() {
        guard !dataDict.isEmpty else {
            param.removeAll()
            return
        }
        
        param.removeAll()
        
        // Sort servo IDs for consistent packet structure
        let sortedServoIds = dataDict.keys.sorted()
        
        for servoId in sortedServoIds {
            guard let data = dataDict[servoId], !data.isEmpty else {
                // Skip servos with no data
                continue
            }
            
            param.append(servoId)
            param.append(contentsOf: data)
        }
        
        isParamChanged = false
    }
}

// MARK: - Group Sync Write Extensions

extension GroupSyncWrite {
    
    /// Convenience method to add multiple servos at once
    /// - Parameter servos: Dictionary of servo ID to data mappings
    /// - Returns: true if all servos were added successfully
    public func addServos(_ servos: [UInt8: [UInt8]]) -> Bool {
        var allSuccessful = true
        
        for (servoId, data) in servos {
            if !addParam(servoId: servoId, data: data) {
                allSuccessful = false
            }
        }
        
        return allSuccessful
    }
    
    /// Convenience method to remove multiple servos at once
    /// - Parameter servoIds: Array of servo IDs to remove
    public func removeServos(_ servoIds: [UInt8]) {
        for servoId in servoIds {
            removeParam(servoId: servoId)
        }
    }
}