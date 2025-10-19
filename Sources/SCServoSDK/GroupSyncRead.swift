import Foundation

// MARK: - Group Sync Read Class

public class GroupSyncRead {
    
    // MARK: - Properties
    
    private let port: PortHandlerProtocol
    private let packetHandler: PacketHandlerProtocol
    private let startAddress: UInt8
    private let dataLength: UInt8
    
    private var lastResult: Bool = false
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
    
    /// Add a servo ID to the sync read group
    /// - Parameter servoId: The ID of the servo to add
    /// - Returns: true if successfully added, false if servo ID already exists
    public func addParam(servoId: UInt8) -> Bool {
        if dataDict[servoId] != nil {
            return false  // servo ID already exists
        }
        
        dataDict[servoId] = []
        isParamChanged = true
        return true
    }
    
    /// Remove a servo ID from the sync read group
    /// - Parameter servoId: The ID of the servo to remove
    public func removeParam(servoId: UInt8) {
        dataDict.removeValue(forKey: servoId)
        isParamChanged = true
    }
    
    /// Clear all parameters from the sync read group
    public func clearParam() {
        dataDict.removeAll()
        isParamChanged = true
    }
    
    /// Transmit the sync read packet
    /// - Returns: Communication result
    public func txPacket() -> CommResult {
        guard !dataDict.isEmpty else {
            return .notAvailable
        }
        
        if isParamChanged || param.isEmpty {
            makeParam()
        }
        
        return packetHandler.syncReadTx(port, startAddress: startAddress, dataLength: dataLength, param: param)
    }
    
    /// Receive sync read response packets
    /// - Returns: Communication result
    public func rxPacket() -> CommResult {
        lastResult = false
        var result: CommResult = .rxFail
        
        guard !dataDict.isEmpty else {
            return .notAvailable
        }
        
        for servoId in dataDict.keys {
            let (data, rxResult, _) = packetHandler.readRx(port, servoId: servoId, length: dataLength)
            dataDict[servoId] = data
            result = rxResult
            
            if result != .success {
                return result
            }
        }
        
        if result == .success {
            lastResult = true
        }
        
        return result
    }
    
    /// Transmit sync read packet and receive responses
    /// - Returns: Communication result
    public func txRxPacket() -> CommResult {
        let result = txPacket()
        if result != .success {
            return result
        }
        
        return rxPacket()
    }
    
    /// Check if data is available for a specific servo and address
    /// - Parameters:
    ///   - servoId: The servo ID
    ///   - address: The address to check
    ///   - dataLength: The length of data to check
    /// - Returns: true if data is available, false otherwise
    public func isAvailable(servoId: UInt8, address: UInt8, dataLength: UInt8) -> Bool {
        guard let servoData = dataDict[servoId] else {
            return false
        }
        
        // Check if address is within the read range
        guard address >= startAddress,
              startAddress + self.dataLength - dataLength >= address else {
            return false
        }
        
        // Check if we have enough data
        guard servoData.count >= dataLength else {
            return false
        }
        
        return true
    }
    
    /// Get data for a specific servo and address
    /// - Parameters:
    ///   - servoId: The servo ID
    ///   - address: The address to read from
    ///   - dataLength: The length of data to read (1, 2, or 4 bytes)
    /// - Returns: The data value, or 0 if not available
    public func getData(servoId: UInt8, address: UInt8, dataLength: UInt8) -> UInt32 {
        guard isAvailable(servoId: servoId, address: address, dataLength: dataLength) else {
            return 0
        }
        
        guard let servoData = dataDict[servoId] else {
            return 0
        }
        
        let offset = Int(address - startAddress)
        
        switch dataLength {
        case 1:
            return UInt32(servoData[offset])
            
        case 2:
            if offset + 1 < servoData.count {
                let word = SCServoUtils.makeWord(servoData[offset], servoData[offset + 1])
                return UInt32(word)
            }
            return 0
            
        case 4:
            if offset + 3 < servoData.count {
                let lowWord = SCServoUtils.makeWord(servoData[offset], servoData[offset + 1])
                let highWord = SCServoUtils.makeWord(servoData[offset + 2], servoData[offset + 3])
                return SCServoUtils.makeDWord(lowWord, highWord)
            }
            return 0
            
        default:
            return 0
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Get 1-byte data for a specific servo and address
    /// - Parameters:
    ///   - servoId: The servo ID
    ///   - address: The address to read from
    /// - Returns: The 1-byte value
    public func getData1Byte(servoId: UInt8, address: UInt8) -> UInt8 {
        return UInt8(getData(servoId: servoId, address: address, dataLength: 1))
    }
    
    /// Get 2-byte data for a specific servo and address
    /// - Parameters:
    ///   - servoId: The servo ID
    ///   - address: The address to read from
    /// - Returns: The 2-byte value
    public func getData2Byte(servoId: UInt8, address: UInt8) -> UInt16 {
        return UInt16(getData(servoId: servoId, address: address, dataLength: 2))
    }
    
    /// Get 4-byte data for a specific servo and address
    /// - Parameters:
    ///   - servoId: The servo ID
    ///   - address: The address to read from
    /// - Returns: The 4-byte value
    public func getData4Byte(servoId: UInt8, address: UInt8) -> UInt32 {
        return getData(servoId: servoId, address: address, dataLength: 4)
    }
    
    /// Get all servo IDs in the group
    /// - Returns: Array of servo IDs
    public func getServoIds() -> [UInt8] {
        return Array(dataDict.keys).sorted()
    }
    
    /// Check if the last operation was successful
    /// - Returns: true if last operation succeeded
    public var wasLastOperationSuccessful: Bool {
        return lastResult
    }
    
    // MARK: - Private Methods
    
    private func makeParam() {
        guard !dataDict.isEmpty else {
            return
        }
        
        param.removeAll()
        
        for servoId in dataDict.keys.sorted() {
            param.append(servoId)
        }
        
        isParamChanged = false
    }
}