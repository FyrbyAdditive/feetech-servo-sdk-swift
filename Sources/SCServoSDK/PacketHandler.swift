import Foundation

// MARK: - Packet Handler Protocol

public protocol PacketHandlerProtocol {
    var protocolVersion: Float { get }
    
    // Basic communication methods
    func ping(_ port: PortHandlerProtocol, servoId: UInt8) -> (modelNumber: UInt16, result: CommResult, error: ProtocolError)
    func action(_ port: PortHandlerProtocol, servoId: UInt8) -> CommResult
    
    // Raw packet transmission
    func txPacket(_ port: PortHandlerProtocol, packet: inout [UInt8]) -> CommResult
    func rxPacket(_ port: PortHandlerProtocol) -> (packet: [UInt8], result: CommResult)
    func txRxPacket(_ port: PortHandlerProtocol, txPacket: inout [UInt8]) -> (rxPacket: [UInt8], result: CommResult, error: ProtocolError)
    
    // Read operations
    func readTx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, length: UInt8) -> CommResult
    func readRx(_ port: PortHandlerProtocol, servoId: UInt8, length: UInt8) -> (data: [UInt8], result: CommResult, error: ProtocolError)
    func readTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, length: UInt8) -> (data: [UInt8], result: CommResult, error: ProtocolError)
    
    // Convenience read methods
    func read1ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8) -> (data: UInt8, result: CommResult, error: ProtocolError)
    func read2ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8) -> (data: UInt16, result: CommResult, error: ProtocolError)
    func read4ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8) -> (data: UInt32, result: CommResult, error: ProtocolError)
    
    // Write operations
    func writeTxOnly(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: [UInt8]) -> CommResult
    func writeTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: [UInt8]) -> (result: CommResult, error: ProtocolError)
    
    // Convenience write methods
    func write1ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: UInt8) -> (result: CommResult, error: ProtocolError)
    func write2ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: UInt16) -> (result: CommResult, error: ProtocolError)
    func write4ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: UInt32) -> (result: CommResult, error: ProtocolError)
    
    // Register write operations
    func regWriteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: [UInt8]) -> (result: CommResult, error: ProtocolError)
    
    // Sync operations
    func syncReadTx(_ port: PortHandlerProtocol, startAddress: UInt8, dataLength: UInt8, param: [UInt8]) -> CommResult
    func syncWriteTxOnly(_ port: PortHandlerProtocol, startAddress: UInt8, dataLength: UInt8, param: [UInt8]) -> CommResult
}

// MARK: - Factory Function

public func createPacketHandler(protocolEnd: Int) -> PacketHandlerProtocol {
    SCServoEndian.setEndianness(protocolEnd)
    return ProtocolPacketHandler()
}

// MARK: - Protocol Packet Handler Implementation

public class ProtocolPacketHandler: PacketHandlerProtocol {
    
    public let protocolVersion: Float = 1.0
    
    // MARK: - Basic Communication
    
    public func ping(_ port: PortHandlerProtocol, servoId: UInt8) -> (modelNumber: UInt16, result: CommResult, error: ProtocolError) {
        var modelNumber: UInt16 = 0
        var error = ProtocolError(rawValue: 0)
        
        guard servoId < SCServoConstants.broadcastId else {
            return (modelNumber, .notAvailable, error)
        }
        
        var txPacket: [UInt8] = [0, 0, 0, 0, 0, 0]
        txPacket[SCServoConstants.pktId] = servoId
        txPacket[SCServoConstants.pktLength] = 2
        txPacket[SCServoConstants.pktInstruction] = SCServoConstants.instPing
        
        let (_, result, rxError) = txRxPacket(port, txPacket: &txPacket)
        
        if result == .success {
            let (data, readResult, readError) = readTxRx(port, servoId: servoId, address: ControlTableAddress.modelNumber, length: 2)
            if readResult == .success {
                modelNumber = SCServoUtils.makeWord(data[0], data[1])
                error = readError
            } else {
                return (modelNumber, readResult, readError)
            }
        }
        
        return (modelNumber, result, rxError)
    }
    
    public func action(_ port: PortHandlerProtocol, servoId: UInt8) -> CommResult {
        var txPacket: [UInt8] = [0, 0, 0, 0, 0, 0]
        txPacket[SCServoConstants.pktId] = servoId
        txPacket[SCServoConstants.pktLength] = 2
        txPacket[SCServoConstants.pktInstruction] = SCServoConstants.instAction
        
        let (_, result, _) = txRxPacket(port, txPacket: &txPacket)
        return result
    }
    
    // MARK: - Raw Packet Operations
    
    public func txPacket(_ port: PortHandlerProtocol, packet: inout [UInt8]) -> CommResult {
        var checksum: UInt8 = 0
        let totalPacketLength = Int(packet[SCServoConstants.pktLength]) + 4
        
        guard let portHandler = port as? PortHandler else {
            return .portBusy
        }
        
        if portHandler.isPortBusy {
            return .portBusy
        }
        portHandler.setPortUsage(true)
        
        // Check max packet length
        guard totalPacketLength <= SCServoConstants.txPacketMaxLen else {
            portHandler.setPortUsage(false)
            return .txError
        }
        
        // Make packet header
        packet[SCServoConstants.pktHeader0] = 0xFF
        packet[SCServoConstants.pktHeader1] = 0xFF
        
        // Calculate checksum
        for i in 2..<(totalPacketLength - 1) {
            checksum = checksum &+ packet[i]
        }
        
        packet[totalPacketLength - 1] = ~checksum
        
        // Transmit packet
        port.clearPort()
        let writtenLength = port.writePort(packet)
        if totalPacketLength != writtenLength {
            portHandler.setPortUsage(false)
            return .txFail
        }
        
        return .success
    }
    
    public func rxPacket(_ port: PortHandlerProtocol) -> (packet: [UInt8], result: CommResult) {
        var rxPacket: [UInt8] = []
        var result: CommResult = .txFail
        var checksum: UInt8 = 0
        var rxLength = 0
        var waitLength = 6  // minimum length (HEADER0 HEADER1 ID LENGTH ERROR CHKSUM)
        
        guard let portHandler = port as? PortHandler else {
            return (rxPacket, .portBusy)
        }
        
        while true {
            let newData = port.readPort(waitLength - rxLength)
            rxPacket.append(contentsOf: newData)
            rxLength = rxPacket.count
            
            if rxLength >= waitLength {
                // Find packet header
                var headerIndex = 0
                for i in 0..<(rxLength - 1) {
                    if rxPacket[i] == 0xFF && rxPacket[i + 1] == 0xFF {
                        headerIndex = i
                        break
                    }
                }
                
                if headerIndex == 0 { // found at the beginning
                    if rxPacket[SCServoConstants.pktId] > 0xFD ||
                       rxPacket[SCServoConstants.pktLength] > SCServoConstants.rxPacketMaxLen ||
                       rxPacket[SCServoConstants.pktError] > 0x7F {
                        // Remove first byte and continue
                        rxPacket.removeFirst()
                        rxLength -= 1
                        continue
                    }
                    
                    // Re-calculate exact packet length
                    let expectedLength = Int(rxPacket[SCServoConstants.pktLength]) + SCServoConstants.pktLength + 1
                    if waitLength != expectedLength {
                        waitLength = expectedLength
                        continue
                    }
                    
                    if rxLength < waitLength {
                        // Check timeout
                        if port.isPacketTimeout() {
                            result = rxLength == 0 ? .rxTimeout : .rxCorrupt
                            break
                        } else {
                            continue
                        }
                    }
                    
                    // Calculate checksum
                    checksum = 0
                    for i in 2..<(waitLength - 1) {
                        checksum = checksum &+ rxPacket[i]
                    }
                    checksum = ~checksum
                    
                    // Verify checksum
                    if rxPacket[waitLength - 1] == checksum {
                        result = .success
                    } else {
                        result = .rxCorrupt
                    }
                    break
                    
                } else {
                    // Remove unnecessary packets
                    rxPacket.removeFirst(headerIndex)
                    rxLength -= headerIndex
                }
            } else {
                // Check timeout
                if port.isPacketTimeout() {
                    result = rxLength == 0 ? .rxTimeout : .rxCorrupt
                    break
                }
            }
        }
        
        portHandler.setPortUsage(false)
        return (rxPacket, result)
    }
    
    public func txRxPacket(_ port: PortHandlerProtocol, txPacket: inout [UInt8]) -> (rxPacket: [UInt8], result: CommResult, error: ProtocolError) {
        var rxPacket: [UInt8] = []
        var error = ProtocolError(rawValue: 0)
        
        // Transmit packet
        let result = self.txPacket(port, packet: &txPacket)
        guard result == .success else {
            return (rxPacket, result, error)
        }
        
        // Check if broadcast - no response expected
        if txPacket[SCServoConstants.pktId] == SCServoConstants.broadcastId {
            if let portHandler = port as? PortHandler {
                portHandler.setPortUsage(false)
            }
            return (rxPacket, result, error)
        }
        
        // Set packet timeout
        if txPacket[SCServoConstants.pktInstruction] == SCServoConstants.instRead {
            port.setPacketTimeout(Int(txPacket[SCServoConstants.pktParameter0 + 1]) + 6)
        } else {
            port.setPacketTimeout(6)
        }
        
        // Receive packet
        while true {
            let (packet, rxResult) = self.rxPacket(port)
            rxPacket = packet
            
            if rxResult != .success || (rxPacket.count > SCServoConstants.pktId && txPacket[SCServoConstants.pktId] == rxPacket[SCServoConstants.pktId]) {
                if rxResult == .success && rxPacket.count > SCServoConstants.pktError {
                    error = ProtocolError(rawValue: rxPacket[SCServoConstants.pktError])
                }
                return (rxPacket, rxResult, error)
            }
        }
    }
    
    // MARK: - Read Operations
    
    public func readTx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, length: UInt8) -> CommResult {
        guard servoId < SCServoConstants.broadcastId else {
            return .notAvailable
        }
        
        var txPacket: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0]
        txPacket[SCServoConstants.pktId] = servoId
        txPacket[SCServoConstants.pktLength] = 4
        txPacket[SCServoConstants.pktInstruction] = SCServoConstants.instRead
        txPacket[SCServoConstants.pktParameter0] = address
        txPacket[SCServoConstants.pktParameter0 + 1] = length
        
        let result = self.txPacket(port, packet: &txPacket)
        
        if result == .success {
            port.setPacketTimeout(Int(length) + 6)
        }
        
        return result
    }
    
    public func readRx(_ port: PortHandlerProtocol, servoId: UInt8, length: UInt8) -> (data: [UInt8], result: CommResult, error: ProtocolError) {
        var data: [UInt8] = []
        var error = ProtocolError(rawValue: 0)
        
        while true {
            let (rxPacket, result) = rxPacket(port)
            
            if result != .success || (rxPacket.count > SCServoConstants.pktId && rxPacket[SCServoConstants.pktId] == servoId) {
                if result == .success && rxPacket.count > SCServoConstants.pktError {
                    error = ProtocolError(rawValue: rxPacket[SCServoConstants.pktError])
                    let paramStart = SCServoConstants.pktParameter0
                    let paramEnd = paramStart + Int(length)
                    if rxPacket.count >= paramEnd {
                        data = Array(rxPacket[paramStart..<paramEnd])
                    }
                }
                return (data, result, error)
            }
        }
    }
    
    public func readTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, length: UInt8) -> (data: [UInt8], result: CommResult, error: ProtocolError) {
        guard servoId < SCServoConstants.broadcastId else {
            return ([], .notAvailable, ProtocolError(rawValue: 0))
        }
        
        var txPacket: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0]
        txPacket[SCServoConstants.pktId] = servoId
        txPacket[SCServoConstants.pktLength] = 4
        txPacket[SCServoConstants.pktInstruction] = SCServoConstants.instRead
        txPacket[SCServoConstants.pktParameter0] = address
        txPacket[SCServoConstants.pktParameter0 + 1] = length
        
        let (rxPacket, result, error) = txRxPacket(port, txPacket: &txPacket)
        
        var data: [UInt8] = []
        if result == .success {
            let paramStart = SCServoConstants.pktParameter0
            let paramEnd = paramStart + Int(length)
            if rxPacket.count >= paramEnd {
                data = Array(rxPacket[paramStart..<paramEnd])
            }
        }
        
        return (data, result, error)
    }
}