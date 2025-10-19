import Foundation

// MARK: - PacketHandler Extension - Convenience Methods

extension ProtocolPacketHandler {
    
    // MARK: - Convenience Read Methods
    
    public func read1ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8) -> (data: UInt8, result: CommResult, error: ProtocolError) {
        let (dataArray, result, error) = readTxRx(port, servoId: servoId, address: address, length: 1)
        let data = result == .success && !dataArray.isEmpty ? dataArray[0] : 0
        return (data, result, error)
    }
    
    public func read2ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8) -> (data: UInt16, result: CommResult, error: ProtocolError) {
        let (dataArray, result, error) = readTxRx(port, servoId: servoId, address: address, length: 2)
        var data: UInt16 = 0
        if result == .success && dataArray.count >= 2 {
            data = SCServoUtils.makeWord(dataArray[0], dataArray[1])
        }
        return (data, result, error)
    }
    
    public func read4ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8) -> (data: UInt32, result: CommResult, error: ProtocolError) {
        let (dataArray, result, error) = readTxRx(port, servoId: servoId, address: address, length: 4)
        var data: UInt32 = 0
        if result == .success && dataArray.count >= 4 {
            let lowWord = SCServoUtils.makeWord(dataArray[0], dataArray[1])
            let highWord = SCServoUtils.makeWord(dataArray[2], dataArray[3])
            data = SCServoUtils.makeDWord(lowWord, highWord)
        }
        return (data, result, error)
    }
    
    // MARK: - Write Operations
    
    public func writeTxOnly(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: [UInt8]) -> CommResult {
        let length = data.count
        var txPacket = [UInt8](repeating: 0, count: length + 7)
        
        txPacket[SCServoConstants.pktId] = servoId
        txPacket[SCServoConstants.pktLength] = UInt8(length + 3)
        txPacket[SCServoConstants.pktInstruction] = SCServoConstants.instWrite
        txPacket[SCServoConstants.pktParameter0] = address
        
        for i in 0..<length {
            txPacket[SCServoConstants.pktParameter0 + 1 + i] = data[i]
        }
        
        let result = self.txPacket(port, packet: &txPacket)
        if let portHandler = port as? PortHandler {
            portHandler.setPortUsage(false)
        }
        
        return result
    }
    
    public func writeTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: [UInt8]) -> (result: CommResult, error: ProtocolError) {
        let length = data.count
        var txPacket = [UInt8](repeating: 0, count: length + 7)
        
        txPacket[SCServoConstants.pktId] = servoId
        txPacket[SCServoConstants.pktLength] = UInt8(length + 3)
        txPacket[SCServoConstants.pktInstruction] = SCServoConstants.instWrite
        txPacket[SCServoConstants.pktParameter0] = address
        
        for i in 0..<length {
            txPacket[SCServoConstants.pktParameter0 + 1 + i] = data[i]
        }
        
        let (_, result, error) = txRxPacket(port, txPacket: &txPacket)
        return (result, error)
    }
    
    // MARK: - Convenience Write Methods
    
    public func write1ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: UInt8) -> (result: CommResult, error: ProtocolError) {
        return writeTxRx(port, servoId: servoId, address: address, data: [data])
    }
    
    public func write2ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: UInt16) -> (result: CommResult, error: ProtocolError) {
        let dataBytes = [SCServoUtils.loByte(data), SCServoUtils.hiByte(data)]
        return writeTxRx(port, servoId: servoId, address: address, data: dataBytes)
    }
    
    public func write4ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: UInt32) -> (result: CommResult, error: ProtocolError) {
        let loWord = SCServoUtils.loWord(data)
        let hiWord = SCServoUtils.hiWord(data)
        let dataBytes = [
            SCServoUtils.loByte(loWord),
            SCServoUtils.hiByte(loWord),
            SCServoUtils.loByte(hiWord),
            SCServoUtils.hiByte(hiWord)
        ]
        return writeTxRx(port, servoId: servoId, address: address, data: dataBytes)
    }
    
    // MARK: - Register Write Operations
    
    public func regWriteTxOnly(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: [UInt8]) -> CommResult {
        let length = data.count
        var txPacket = [UInt8](repeating: 0, count: length + 7)
        
        txPacket[SCServoConstants.pktId] = servoId
        txPacket[SCServoConstants.pktLength] = UInt8(length + 3)
        txPacket[SCServoConstants.pktInstruction] = SCServoConstants.instRegWrite
        txPacket[SCServoConstants.pktParameter0] = address
        
        for i in 0..<length {
            txPacket[SCServoConstants.pktParameter0 + 1 + i] = data[i]
        }
        
        let result = self.txPacket(port, packet: &txPacket)
        if let portHandler = port as? PortHandler {
            portHandler.setPortUsage(false)
        }
        
        return result
    }
    
    public func regWriteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: [UInt8]) -> (result: CommResult, error: ProtocolError) {
        let length = data.count
        var txPacket = [UInt8](repeating: 0, count: length + 7)
        
        txPacket[SCServoConstants.pktId] = servoId
        txPacket[SCServoConstants.pktLength] = UInt8(length + 3)
        txPacket[SCServoConstants.pktInstruction] = SCServoConstants.instRegWrite
        txPacket[SCServoConstants.pktParameter0] = address
        
        for i in 0..<length {
            txPacket[SCServoConstants.pktParameter0 + 1 + i] = data[i]
        }
        
        let (_, result, error) = txRxPacket(port, txPacket: &txPacket)
        return (result, error)
    }
    
    // MARK: - Sync Operations
    
    public func syncReadTx(_ port: PortHandlerProtocol, startAddress: UInt8, dataLength: UInt8, param: [UInt8]) -> CommResult {
        let paramLength = param.count
        var txPacket = [UInt8](repeating: 0, count: paramLength + 8)
        
        txPacket[SCServoConstants.pktId] = SCServoConstants.broadcastId
        txPacket[SCServoConstants.pktLength] = UInt8(paramLength + 4)
        txPacket[SCServoConstants.pktInstruction] = SCServoConstants.instSyncRead
        txPacket[SCServoConstants.pktParameter0] = startAddress
        txPacket[SCServoConstants.pktParameter0 + 1] = dataLength
        
        for i in 0..<paramLength {
            txPacket[SCServoConstants.pktParameter0 + 2 + i] = param[i]
        }
        
        let result = self.txPacket(port, packet: &txPacket)
        if result == .success {
            port.setPacketTimeout((6 + Int(dataLength)) * paramLength)
        }
        
        return result
    }
    
    public func syncWriteTxOnly(_ port: PortHandlerProtocol, startAddress: UInt8, dataLength: UInt8, param: [UInt8]) -> CommResult {
        let paramLength = param.count
        var txPacket = [UInt8](repeating: 0, count: paramLength + 8)
        
        txPacket[SCServoConstants.pktId] = SCServoConstants.broadcastId
        txPacket[SCServoConstants.pktLength] = UInt8(paramLength + 4)
        txPacket[SCServoConstants.pktInstruction] = SCServoConstants.instSyncWrite
        txPacket[SCServoConstants.pktParameter0] = startAddress
        txPacket[SCServoConstants.pktParameter0 + 1] = dataLength
        
        for i in 0..<paramLength {
            txPacket[SCServoConstants.pktParameter0 + 2 + i] = param[i]
        }
        
        let (_, result, _) = self.txRxPacket(port, txPacket: &txPacket)
        return result
    }
}