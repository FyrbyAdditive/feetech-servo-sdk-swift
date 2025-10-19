import Foundation
import Darwin

// MARK: - Serial Port Error

public enum SerialPortError: Error {
    case failedToOpen
    case failedToSetBaudRate
    case failedToRead
    case failedToWrite
    case invalidBaudRate
    case portNotOpen
    case timeout
    
    public var localizedDescription: String {
        switch self {
        case .failedToOpen:
            return "Failed to open serial port"
        case .failedToSetBaudRate:
            return "Failed to set baud rate"
        case .failedToRead:
            return "Failed to read from serial port"
        case .failedToWrite:
            return "Failed to write to serial port"
        case .invalidBaudRate:
            return "Invalid baud rate"
        case .portNotOpen:
            return "Serial port is not open"
        case .timeout:
            return "Operation timed out"
        }
    }
}

// MARK: - Port Handler Protocol

public protocol PortHandlerProtocol {
    var isOpen: Bool { get }
    var baudRate: UInt32 { get }
    var portName: String { get }
    
    func openPort() throws
    func closePort()
    func clearPort()
    func setBaudRate(_ baudRate: UInt32) throws
    func getBytesAvailable() -> Int
    func readPort(_ length: Int) -> [UInt8]
    func writePort(_ data: [UInt8]) -> Int
    func setPacketTimeout(_ packetLength: Int)
    func setPacketTimeoutMillis(_ milliseconds: Double)
    func isPacketTimeout() -> Bool
}

// MARK: - Port Handler Implementation

public class PortHandler: PortHandlerProtocol {
    
    // MARK: - Properties
    
    public private(set) var isOpen: Bool = false
    public private(set) var baudRate: UInt32 = SCServoConstants.defaultBaudrate
    public private(set) var portName: String
    
    private var fileDescriptor: Int32 = -1
    private var packetStartTime: Double = 0.0
    private var packetTimeout: Double = 0.0
    private var txTimePerByte: Double = 0.0
    private var isUsing: Bool = false
    
    // MARK: - Initialization
    
    public init(portName: String) {
        self.portName = portName
    }
    
    deinit {
        if isOpen {
            closePort()
        }
    }
    
    // MARK: - Port Management
    
    public func openPort() throws {
        try setBaudRate(baudRate)
    }
    
    public func closePort() {
        if fileDescriptor >= 0 {
            Darwin.close(fileDescriptor)
            fileDescriptor = -1
        }
        isOpen = false
    }
    
    public func clearPort() {
        guard isOpen else { return }
        // Flush both input and output buffers
        tcflush(fileDescriptor, TCIOFLUSH)
    }
    
    public func setPortName(_ portName: String) {
        self.portName = portName
    }
    
    public func setBaudRate(_ baudRate: UInt32) throws {
        let speedConstant = getSpeedConstant(for: baudRate)
        guard speedConstant > 0 else {
            throw SerialPortError.invalidBaudRate
        }
        
        self.baudRate = baudRate
        try setupPort(speedConstant: speedConstant)
    }
    
    // MARK: - Data I/O
    
    public func getBytesAvailable() -> Int {
        guard isOpen else { return 0 }
        
        var bytesAvailable: Int32 = 0
        let fionread: UInt = 0x4004667f  // FIONREAD constant for macOS
        if ioctl(fileDescriptor, fionread, &bytesAvailable) == -1 {
            return 0
        }
        return Int(bytesAvailable)
    }
    
    public func readPort(_ length: Int) -> [UInt8] {
        guard isOpen && length > 0 else { return [] }
        
        var buffer = [UInt8](repeating: 0, count: length)
        let bytesRead = Darwin.read(fileDescriptor, &buffer, length)
        
        if bytesRead > 0 {
            return Array(buffer.prefix(bytesRead))
        }
        return []
    }
    
    public func writePort(_ data: [UInt8]) -> Int {
        guard isOpen else { return 0 }
        
        var totalWritten = 0
        var remainingData = data
        let maxAttempts = 10
        var attempts = 0
        
        while !remainingData.isEmpty && attempts < maxAttempts {
            attempts += 1
            
            // Port is ready, try to write
            let bytesWritten = remainingData.withUnsafeBufferPointer { bufferPointer in
                Darwin.write(fileDescriptor, bufferPointer.baseAddress, remainingData.count)
            }
            
            if bytesWritten < 0 {
                let error = errno
                if error == EAGAIN || error == EWOULDBLOCK {
                    // Port not ready, wait a bit and try again
                    usleep(1000) // Wait 1ms
                    continue
                }
                // Write failed with an error
                break
            } else if bytesWritten == 0 {
                // No data written, wait and retry
                usleep(1000) // Wait 1ms
                continue
            } else {
                totalWritten += bytesWritten
                if bytesWritten < remainingData.count {
                    remainingData.removeFirst(bytesWritten)
                } else {
                    break // All data written
                }
            }
        }
        
        return totalWritten
    }
    
    // MARK: - Timeout Management
    
    public func setPacketTimeout(_ packetLength: Int) {
        packetStartTime = getCurrentTime()
        packetTimeout = (txTimePerByte * Double(packetLength)) + (SCServoConstants.latencyTimer * 2.0) + 2.0
    }
    
    public func setPacketTimeoutMillis(_ milliseconds: Double) {
        packetStartTime = getCurrentTime()
        packetTimeout = milliseconds
    }
    
    public func isPacketTimeout() -> Bool {
        if getTimeSinceStart() > packetTimeout {
            packetTimeout = 0
            return true
        }
        return false
    }
    
    // MARK: - Private Methods
    
    private func getCurrentTime() -> Double {
        let timespec = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        return Double(timespec) / 1_000_000.0  // Convert nanoseconds to milliseconds
    }
    
    private func getTimeSinceStart() -> Double {
        let timeSince = getCurrentTime() - packetStartTime
        if timeSince < 0.0 {
            packetStartTime = getCurrentTime()
            return 0.0
        }
        return timeSince
    }
    
    private func setupPort(speedConstant: speed_t) throws {
        if isOpen {
            closePort()
        }
        
        // Open the serial port
        fileDescriptor = Darwin.open(portName, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fileDescriptor >= 0 else {
            throw SerialPortError.failedToOpen
        }
        
        // Configure the port
        var options = termios()
        
        // Get current port settings
        if tcgetattr(fileDescriptor, &options) != 0 {
            Darwin.close(fileDescriptor)
            fileDescriptor = -1
            throw SerialPortError.failedToOpen
        }
        
        // Configure for raw mode first
        options.c_iflag &= ~tcflag_t(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON)
        options.c_oflag &= ~tcflag_t(OPOST)
        options.c_lflag &= ~tcflag_t(ECHO | ECHONL | ICANON | ISIG | IEXTEN)
        options.c_cflag &= ~tcflag_t(CSIZE | PARENB)
        options.c_cflag |= tcflag_t(CS8)
        
        // Set timeout and minimum characters
        options.c_cc.16 = 0  // VMIN = 0
        options.c_cc.17 = 0  // VTIME = 0
        
        // Set standard baud rate if available
        if speedConstant > 0 && speedConstant != baudRate {
            cfsetispeed(&options, speedConstant)
            cfsetospeed(&options, speedConstant)
        }
        
        // Apply the settings
        if tcsetattr(fileDescriptor, TCSANOW, &options) != 0 {
            Darwin.close(fileDescriptor)
            fileDescriptor = -1
            throw SerialPortError.failedToSetBaudRate
        }
        
        // For custom baud rates (like 1000000), use ioctl with IOSSIOSPEED
        if speedConstant == baudRate {
            var customSpeed = baudRate
            let IOSSIOSPEED: UInt = 0x80045402  // ioctl constant for setting custom speed on macOS
            if ioctl(fileDescriptor, IOSSIOSPEED, &customSpeed) == -1 {
                Darwin.close(fileDescriptor)
                fileDescriptor = -1
                throw SerialPortError.failedToSetBaudRate
            }
        }
        
        // Flush any existing data
        tcflush(fileDescriptor, TCIOFLUSH)
        
        isOpen = true
        txTimePerByte = (1000.0 / Double(baudRate)) * 10.0
    }
    
    private func getSpeedConstant(for baudRate: UInt32) -> speed_t {
        switch baudRate {
        case 4800: return speed_t(B4800)
        case 9600: return speed_t(B9600)
        case 19200: return speed_t(B19200)
        case 38400: return speed_t(B38400)
        case 57600: return speed_t(B57600)
        case 115200: return speed_t(B115200)
        case 230400: return speed_t(B230400)
        case 1000000:
            // Custom handling for 1000000 baud rate
            return speed_t(1000000)
        default:
            return 0  // Invalid baud rate
        }
    }
}

// MARK: - Port Handler Extensions

extension PortHandler {
    
    /// Check if the port is currently being used
    public var isPortBusy: Bool {
        return isUsing
    }
    
    /// Set the port usage state
    public func setPortUsage(_ inUse: Bool) {
        isUsing = inUse
    }
    
    /// Get a list of available serial ports on macOS
    public static func availablePorts() -> [String] {
        let fileManager = FileManager.default
        let devPath = "/dev"
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: devPath)
            return contents.filter { $0.hasPrefix("tty.") || $0.hasPrefix("cu.") }
                          .map { "\(devPath)/\($0)" }
                          .sorted()
        } catch {
            return []
        }
    }
}