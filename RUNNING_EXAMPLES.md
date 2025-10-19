# How to Run the SCServo Swift Examples

## Prerequisites

1. **Hardware Setup**
   - Feetech SCServo motor (STS, SMS, or SCS series)
   - USB to TTL serial converter (3.3V or 5V compatible)
   - Proper power supply for your servo
   - Connect servo data line to serial converter TX/RX pins

2. **Software Requirements**
   - macOS 10.15+ (for development)
   - Swift 5.7+
   - Xcode or Swift Package Manager

## Quick Start - Running the Ping Example

### Step 1: Navigate to the Project Directory

```bash
cd /Users/tim/VSCode/feetech-servo-swift/SCServoSwift
```

### Step 2: Update Device Configuration

Before running, you need to update the device path to match your system. Edit the configuration in the ping example:

```swift
// In Sources/PingExample/main.swift, update this line:
static let deviceName = "/dev/tty.usbserial-*" // Change to your actual device
```

**Finding Your Device Path:**

On macOS, common device paths are:
- `/dev/tty.usbserial-*` (FTDI devices)
- `/dev/tty.usbmodem*` (CDC ACM devices)
- `/dev/cu.usbserial-*` (alternative naming)

You can list available devices with:
```bash
ls /dev/tty.*
ls /dev/cu.*
```

### Step 3: Build and Run

#### Method 1: Using Swift Package Manager (Recommended)

```bash
# Build the project
swift build

# Run the ping example
swift run PingExample
```

#### Method 2: Using Xcode

1. Open the package in Xcode:
   ```bash
   open Package.swift
   ```

2. Select the "PingExample" scheme in Xcode
3. Press Cmd+R to build and run

### Step 4: Expected Output

If everything is working correctly, you should see:

```
Starting SCServo Swift Ping Example...
Make sure your servo is connected and powered on.

Available serial ports:
  - /dev/tty.usbserial-A12345
  - /dev/cu.usbserial-A12345

Update ServoConfiguration.deviceName to match your device.
Current setting: /dev/tty.usbserial-*

✓ Succeeded to open the port: /dev/tty.usbserial-A12345
✓ Succeeded to change the baudrate to 1000000

Pinging servo with ID 1...
✓ [ID:001] ping Succeeded!
  Servo model number: 1000

Port closed. Example completed.
```

## Running Other Examples

### Read/Write Example
```bash
swift run ReadWriteExample
```
This example demonstrates reading and writing servo positions.

### Sync Read/Write Example
```bash
swift run SyncReadWriteExample
```
This example shows synchronized operations with multiple servos.

## Troubleshooting

### Common Issues and Solutions

#### 1. "Failed to open the port"

**Causes:**
- Incorrect device path
- Permission issues
- Device not connected

**Solutions:**
```bash
# Check device permissions
ls -la /dev/tty.usbserial-*

# Add user to dialout group (if needed)
sudo dseditgroup -o edit -a $(whoami) -t user _developer

# Try different device paths
ls /dev/{tty,cu}.{usbserial,usbmodem}*
```

#### 2. "Communication failed: rxTimeout"

**Causes:**
- Wrong servo ID
- Incorrect baud rate
- Servo not powered
- Wrong protocol endianness

**Solutions:**
```swift
// Try different servo ID
static let servoId: UInt8 = 1  // Try IDs 1, 2, 3, etc.

// Try different baud rate
static let baudRate: UInt32 = 115200  // Instead of 1000000

// Try different protocol endianness
static let protocolEnd = 1  // Instead of 0 (for SCS series)
```

#### 3. "Invalid baud rate"

**Solution:**
Use one of the supported baud rates:
- 1000000 (most common)
- 115200
- 57600
- 38400
- 19200
- 9600

#### 4. Permission Denied

**On macOS:**
```bash
# Check current user groups
id

# If needed, try running with sudo (not recommended for development)
sudo swift run PingExample
```

**Better solution - Fix permissions:**
1. Unplug and replug the USB device
2. Check System Preferences → Security & Privacy
3. Make sure Terminal/Xcode has necessary permissions

## Configuration Options

### Servo Configuration

You can modify these settings in each example:

```swift
struct ServoConfiguration {
    static let servoId: UInt8 = 1           // Servo ID (1-252)
    static let baudRate: UInt32 = 1000000   // Communication speed
    static let deviceName = "/dev/tty.usbserial-*"  // Device path
    static let protocolEnd = 0              // Protocol endianness
}
```

### Protocol Endianness

- **STS/SMS series:** `protocolEnd = 0`
- **SCS series:** `protocolEnd = 1`

### Common Baud Rates by Servo Model

- **Most Feetech servos:** 1000000 (default)
- **Some older models:** 115200
- **Debugging/long cables:** 57600 or lower

## Advanced Usage

### Custom Device Path

If your device has a different path, update it directly:

```swift
// Example for a specific FTDI device
static let deviceName = "/dev/tty.usbserial-A12345"

// Example for a CDC ACM device  
static let deviceName = "/dev/tty.usbmodem12345"
```

### Batch Operations

To run multiple examples in sequence:

```bash
# Build all examples
swift build

# Run them in order
swift run PingExample && swift run ReadWriteExample
```

### Debug Mode

Add debug output by modifying the source:

```swift
#if DEBUG
print("Debug: Sending ping to servo \(servoId)")
print("Debug: Using device \(deviceName)")
#endif
```

## Development Tips

1. **Start Simple:** Always test with the ping example first
2. **Check Hardware:** Verify power, connections, and servo ID
3. **Use Correct Settings:** Match baud rate and protocol to your servo
4. **Monitor Serial:** Use a serial monitor to debug communication
5. **Test Incrementally:** Add one servo at a time for multi-servo setups

## Next Steps

Once the ping example works:

1. Try the ReadWrite example for basic motion control
2. Experiment with different positions and speeds
3. Use the Sync example for coordinated multi-servo control
4. Integrate the library into your own Swift projects

For more detailed API documentation, see `API_REFERENCE.md`.