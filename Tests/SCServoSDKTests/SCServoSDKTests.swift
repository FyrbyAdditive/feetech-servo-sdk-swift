import XCTest
@testable import SCServoSDK

final class SCServoSDKTests: XCTestCase {
    
    func testUtilityFunctions() {
        // Test makeWord function
        let word = SCServoUtils.makeWord(0x34, 0x12)
        XCTAssertEqual(word, 0x1234)
        
        // Test makeDWord function
        let dword = SCServoUtils.makeDWord(0x5678, 0x1234)
        XCTAssertEqual(dword, 0x12345678)
        
        // Test byte extraction
        let testWord: UInt16 = 0x1234
        XCTAssertEqual(SCServoUtils.loByte(testWord), 0x34)
        XCTAssertEqual(SCServoUtils.hiByte(testWord), 0x12)
        
        // Test word extraction
        let testDWord: UInt32 = 0x12345678
        XCTAssertEqual(SCServoUtils.loWord(testDWord), 0x5678)
        XCTAssertEqual(SCServoUtils.hiWord(testDWord), 0x1234)
    }
    
    func testCommResultDescriptions() {
        XCTAssertEqual(CommResult.success.description, "[TxRxResult] Communication success!")
        XCTAssertEqual(CommResult.txFail.description, "[TxRxResult] Failed transmit instruction packet!")
        XCTAssertEqual(CommResult.rxTimeout.description, "[TxRxResult] There is no status packet!")
    }
    
    func testProtocolErrorDescriptions() {
        let voltageError = ProtocolError.voltage
        XCTAssertTrue(voltageError.description.contains("Input voltage error"))
        
        let combinedError: ProtocolError = [.voltage, .overheat]
        XCTAssertTrue(combinedError.description.contains("Input voltage error"))
        XCTAssertTrue(combinedError.description.contains("Overheat error"))
    }
    
    func testEndianConfiguration() {
        // Test endian configuration
        SCServoEndian.setEndianness(0)
        XCTAssertEqual(SCServoEndian.getEndianness(), 0)
        
        SCServoEndian.setEndianness(1)
        XCTAssertEqual(SCServoEndian.getEndianness(), 1)
    }
    
    func testConstants() {
        // Test basic constants
        XCTAssertEqual(SCServoConstants.broadcastId, 0xFE)
        XCTAssertEqual(SCServoConstants.maxId, 0xFC)
        XCTAssertEqual(SCServoConstants.defaultBaudrate, 1000000)
        
        // Test instruction constants
        XCTAssertEqual(SCServoConstants.instPing, 1)
        XCTAssertEqual(SCServoConstants.instRead, 2)
        XCTAssertEqual(SCServoConstants.instWrite, 3)
    }
    
    func testControlTableAddresses() {
        XCTAssertEqual(ControlTableAddress.torqueEnable, 40)
        XCTAssertEqual(ControlTableAddress.goalPosition, 42)
        XCTAssertEqual(ControlTableAddress.presentPosition, 56)
    }
    
    func testGroupSyncWriteBasicOperations() {
        // Create mock implementations for testing
        let mockPort = MockPortHandler()
        let mockPacketHandler = MockPacketHandler()
        
        let syncWrite = GroupSyncWrite(
            port: mockPort,
            packetHandler: mockPacketHandler,
            startAddress: 42,
            dataLength: 2
        )
        
        // Test adding parameters
        XCTAssertTrue(syncWrite.addParam2Byte(servoId: 1, data: 1024))
        XCTAssertTrue(syncWrite.addParam2Byte(servoId: 2, data: 2048))
        
        // Test servo count
        XCTAssertEqual(syncWrite.servoCount, 2)
        XCTAssertFalse(syncWrite.isEmpty)
        
        // Test servo existence
        XCTAssertTrue(syncWrite.hasServo(1))
        XCTAssertTrue(syncWrite.hasServo(2))
        XCTAssertFalse(syncWrite.hasServo(3))
        
        // Test duplicate addition
        XCTAssertFalse(syncWrite.addParam2Byte(servoId: 1, data: 512))
        
        // Test removal
        syncWrite.removeParam(servoId: 1)
        XCTAssertEqual(syncWrite.servoCount, 1)
        XCTAssertFalse(syncWrite.hasServo(1))
        
        // Test clear
        syncWrite.clearParam()
        XCTAssertEqual(syncWrite.servoCount, 0)
        XCTAssertTrue(syncWrite.isEmpty)
    }
    
    func testGroupSyncReadBasicOperations() {
        let mockPort = MockPortHandler()
        let mockPacketHandler = MockPacketHandler()
        
        let syncRead = GroupSyncRead(
            port: mockPort,
            packetHandler: mockPacketHandler,
            startAddress: 56,
            dataLength: 4
        )
        
        // Test adding parameters
        XCTAssertTrue(syncRead.addParam(servoId: 1))
        XCTAssertTrue(syncRead.addParam(servoId: 2))
        
        // Test duplicate addition
        XCTAssertFalse(syncRead.addParam(servoId: 1))
        
        // Test servo IDs
        let servoIds = syncRead.getServoIds()
        XCTAssertEqual(servoIds.sorted(), [1, 2])
        
        // Test removal
        syncRead.removeParam(servoId: 1)
        XCTAssertEqual(syncRead.getServoIds(), [2])
        
        // Test clear
        syncRead.clearParam()
        XCTAssertTrue(syncRead.getServoIds().isEmpty)
    }
}

// MARK: - Mock Classes for Testing

class MockPortHandler: PortHandlerProtocol {
    var isOpen: Bool = true
    var baudRate: UInt32 = 1000000
    var portName: String = "mock"
    
    func openPort() throws {}
    func closePort() {}
    func clearPort() {}
    func setBaudRate(_ baudRate: UInt32) throws {}
    func getBytesAvailable() -> Int { return 0 }
    func readPort(_ length: Int) -> [UInt8] { return [] }
    func writePort(_ data: [UInt8]) -> Int { return data.count }
    func setPacketTimeout(_ packetLength: Int) {}
    func setPacketTimeoutMillis(_ milliseconds: Double) {}
    func isPacketTimeout() -> Bool { return false }
}

class MockPacketHandler: PacketHandlerProtocol {
    var protocolVersion: Float = 1.0
    
    func ping(_ port: PortHandlerProtocol, servoId: UInt8) -> (modelNumber: UInt16, result: CommResult, error: ProtocolError) {
        return (1000, .success, ProtocolError(rawValue: 0))
    }
    
    func action(_ port: PortHandlerProtocol, servoId: UInt8) -> CommResult {
        return .success
    }
    
    func txPacket(_ port: PortHandlerProtocol, packet: inout [UInt8]) -> CommResult {
        return .success
    }
    
    func rxPacket(_ port: PortHandlerProtocol) -> (packet: [UInt8], result: CommResult) {
        return ([], .success)
    }
    
    func txRxPacket(_ port: PortHandlerProtocol, txPacket: inout [UInt8]) -> (rxPacket: [UInt8], result: CommResult, error: ProtocolError) {
        return ([], .success, ProtocolError(rawValue: 0))
    }
    
    func readTx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, length: UInt8) -> CommResult {
        return .success
    }
    
    func readRx(_ port: PortHandlerProtocol, servoId: UInt8, length: UInt8) -> (data: [UInt8], result: CommResult, error: ProtocolError) {
        return ([], .success, ProtocolError(rawValue: 0))
    }
    
    func readTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, length: UInt8) -> (data: [UInt8], result: CommResult, error: ProtocolError) {
        return ([], .success, ProtocolError(rawValue: 0))
    }
    
    func read1ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8) -> (data: UInt8, result: CommResult, error: ProtocolError) {
        return (0, .success, ProtocolError(rawValue: 0))
    }
    
    func read2ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8) -> (data: UInt16, result: CommResult, error: ProtocolError) {
        return (0, .success, ProtocolError(rawValue: 0))
    }
    
    func read4ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8) -> (data: UInt32, result: CommResult, error: ProtocolError) {
        return (0, .success, ProtocolError(rawValue: 0))
    }
    
    func writeTxOnly(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: [UInt8]) -> CommResult {
        return .success
    }
    
    func writeTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: [UInt8]) -> (result: CommResult, error: ProtocolError) {
        return (.success, ProtocolError(rawValue: 0))
    }
    
    func write1ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: UInt8) -> (result: CommResult, error: ProtocolError) {
        return (.success, ProtocolError(rawValue: 0))
    }
    
    func write2ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: UInt16) -> (result: CommResult, error: ProtocolError) {
        return (.success, ProtocolError(rawValue: 0))
    }
    
    func write4ByteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: UInt32) -> (result: CommResult, error: ProtocolError) {
        return (.success, ProtocolError(rawValue: 0))
    }
    
    func regWriteTxRx(_ port: PortHandlerProtocol, servoId: UInt8, address: UInt8, data: [UInt8]) -> (result: CommResult, error: ProtocolError) {
        return (.success, ProtocolError(rawValue: 0))
    }
    
    func syncReadTx(_ port: PortHandlerProtocol, startAddress: UInt8, dataLength: UInt8, param: [UInt8]) -> CommResult {
        return .success
    }
    
    func syncWriteTxOnly(_ port: PortHandlerProtocol, startAddress: UInt8, dataLength: UInt8, param: [UInt8]) -> CommResult {
        return .success
    }
}