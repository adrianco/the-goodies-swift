# Bertha iOS App Testing Guide

## Overview
Bertha is a SwiftUI test application designed to validate the Wildthing and Inbetweenies Swift packages. This guide covers setting up, running, and testing Bertha in the Xcode simulator.

## Prerequisites

- macOS with Xcode 15.0 or later
- iOS Simulator (iOS 15.0+)
- FunkyGibbon server running (see FUNKYGIBBON_SETUP_GUIDE.md)
- Git

## Project Setup

### 1. Open the Project

```bash
# Navigate to the bertha directory
cd /workspaces/the-goodies-swift/bertha

# Open in Xcode
open bertha.xcodeproj
```

Or manually:
1. Launch Xcode
2. Select "Open a project or file"
3. Navigate to `the-goodies-swift/bertha/`
4. Select `bertha.xcodeproj`

### 2. Configure Package Dependencies

The project should automatically resolve Swift Package dependencies:
- Wildthing (local package)
- Inbetweenies (local package)
- SQLite.swift (via SPM)

If packages don't resolve:
1. Select the project in navigator
2. Go to "Package Dependencies" tab
3. Click "Resolve Package Versions"

### 3. Select Target Device

1. In Xcode toolbar, click the device selector
2. Choose an iOS Simulator:
   - Recommended: iPhone 15 Pro (iOS 17.0+)
   - Minimum: iPhone 12 (iOS 15.0+)

## Building and Running

### 1. Clean Build Folder (Optional)

```
Product → Clean Build Folder (⌘⇧K)
```

### 2. Build the Project

```
Product → Build (⌘B)
```

Watch for any compilation errors in the Issue Navigator.

### 3. Run in Simulator

```
Product → Run (⌘R)
```

The iOS Simulator will launch and install Bertha.

## Testing Features

### 1. Home Tab
- Displays welcome message
- Shows app version and status
- Provides navigation to other features

### 2. Connection Tab

#### Testing Server Connection:

1. **Start FunkyGibbon Server**
   ```bash
   # In terminal
   cd path/to/funkygibbon
   uvicorn main:app --host 0.0.0.0 --port 8000
   ```

2. **Configure Connection in Bertha**
   - Tap "Connect" tab
   - Enter Server URL:
     - For local server: `http://localhost:8000`
     - For network server: `http://[server-ip]:8000`
   - Enter Client ID: `test-client`
   - Enter Password: `test-password`

3. **Test Connection**
   - Tap "Connect" button
   - Verify green checkmark appears
   - Check "Connected" status

#### Connection Troubleshooting:

**"Cannot connect to server" error:**
- Verify FunkyGibbon is running
- Check server URL is correct
- For localhost, try `http://127.0.0.1:8000`

**Authentication failed:**
- Verify credentials match server configuration
- Check server logs for auth errors

**Network issues in Simulator:**
- Reset simulator network: Device → Erase All Content and Settings
- Check Mac's network connection
- Disable Mac firewall temporarily for testing

### 3. Entities Tab (Planned Features)

Once connected, test entity operations:

1. **Create Entity**
   - Tap "+" button
   - Fill in entity details:
     - Name: "Living Room"
     - Type: Room
     - Properties: Add custom fields
   - Save entity

2. **View Entities**
   - Check entity list updates
   - Verify sync indicator
   - Pull to refresh

3. **Edit Entity**
   - Tap on entity
   - Modify properties
   - Save changes
   - Verify sync

4. **Delete Entity**
   - Swipe left on entity
   - Tap Delete
   - Confirm deletion

### 4. Settings Tab (Planned Features)

Test configuration options:
- Auto-sync interval
- Offline mode toggle
- Cache management
- Debug logging

## Testing Synchronization

### 1. Online Sync Test

1. Create entity in Bertha
2. Verify in server database:
   ```bash
   sqlite3 funkygibbon.db
   SELECT * FROM entities;
   ```
3. Modify entity on server
4. Pull to refresh in Bertha
5. Verify changes appear

### 2. Offline Mode Test

1. Enable Airplane Mode in Simulator
2. Create/modify entities
3. Check pending changes indicator
4. Disable Airplane Mode
5. Verify automatic sync

### 3. Conflict Resolution Test

1. Create entity in Bertha
2. Modify same entity on server
3. Modify entity in Bertha (while offline)
4. Reconnect and sync
5. Verify conflict resolution

## Debugging in Xcode

### 1. View Console Logs

```
View → Debug Area → Show Debug Area (⌘⇧Y)
```

Monitor for:
- Network requests
- Sync operations
- Error messages
- SQLite queries

### 2. Set Breakpoints

Click line numbers to set breakpoints in:
- `WildthingClientV2.swift` - Connection logic
- `SyncEngine.swift` - Sync operations
- `LocalStorage.swift` - Database operations

### 3. Network Debugging

1. Enable Network Link Conditioner:
   - Xcode → Open Developer Tool → More Developer Tools
   - Download Additional Tools for Xcode
   - Install Network Link Conditioner

2. Test with various conditions:
   - 100% Loss (offline)
   - 3G speed
   - High latency

### 4. View SQLite Database

```bash
# Find app container
xcrun simctl get_app_container booted com.yourcompany.bertha data

# Navigate to database
cd [container-path]/Documents
sqlite3 wildthing.db
.tables
```

## UI Testing

### 1. Manual Testing Checklist

- [ ] App launches without crash
- [ ] All tabs are accessible
- [ ] Connection form validates input
- [ ] Connection status updates correctly
- [ ] Network changes are detected
- [ ] Offline mode works
- [ ] Data persists between launches
- [ ] Memory usage is reasonable
- [ ] No UI freezes during sync

### 2. Automated UI Tests

In Xcode:
1. Open `berthaUITests.swift`
2. Add test cases:

```swift
func testConnection() throws {
    let app = XCUIApplication()
    app.launch()
    
    // Navigate to Connection tab
    app.tabBars.buttons["Connect"].tap()
    
    // Enter credentials
    app.textFields["Server URL"].tap()
    app.textFields["Server URL"].typeText("http://localhost:8000")
    
    app.textFields["Client ID"].tap()
    app.textFields["Client ID"].typeText("test-client")
    
    app.secureTextFields["Password"].tap()
    app.secureTextFields["Password"].typeText("test-password")
    
    // Connect
    app.buttons["Connect"].tap()
    
    // Verify connection
    XCTAssertTrue(app.staticTexts["Connected"].exists)
}
```

Run UI tests: `Product → Test (⌘U)`

## Performance Testing

### 1. Memory Profiling

1. Product → Profile (⌘I)
2. Choose "Leaks" template
3. Run and interact with app
4. Check for memory leaks

### 2. Network Profiling

1. Product → Profile
2. Choose "Network" template
3. Monitor request timing
4. Check data usage

### 3. Time Profiler

1. Product → Profile
2. Choose "Time Profiler"
3. Identify performance bottlenecks
4. Optimize slow operations

## Common Issues and Solutions

### Build Errors

**"No such module 'Wildthing'"**
- Clean build folder (⌘⇧K)
- Reset package caches
- Check package dependencies

**"Cannot find type 'Entity' in scope"**
- Verify Inbetweenies package is linked
- Check import statements

### Runtime Errors

**"Database is locked"**
- Reset simulator
- Delete app and reinstall

**"Network connection lost"**
- Check server is running
- Verify network settings
- Reset simulator network

### Simulator Issues

**Simulator won't launch:**
```bash
# Reset simulator
xcrun simctl erase all
```

**Keyboard not showing:**
- Hardware → Keyboard → Toggle Software Keyboard (⌘K)

## Testing Checklist

### Initial Setup
- [ ] Xcode project opens
- [ ] Dependencies resolve
- [ ] Project builds without errors
- [ ] Simulator launches

### Connection Testing
- [ ] Can enter server details
- [ ] Connection succeeds with valid credentials
- [ ] Connection fails with invalid credentials
- [ ] Status updates correctly

### Data Operations
- [ ] Can create entities
- [ ] Can view entity list
- [ ] Can edit entities
- [ ] Can delete entities
- [ ] Changes sync to server

### Offline Functionality
- [ ] App works offline
- [ ] Changes queue while offline
- [ ] Sync resumes when online
- [ ] No data loss

### Performance
- [ ] App remains responsive
- [ ] Memory usage acceptable
- [ ] No memory leaks
- [ ] Network requests efficient

## Next Steps

1. Test with real devices (requires Apple Developer account)
2. Test with multiple users simultaneously
3. Test with large datasets
4. Test migration scenarios
5. Beta testing with TestFlight

## Support

For issues:
1. Check Xcode console for error messages
2. Review server logs
3. Check Swift package implementations
4. File issues at: https://github.com/adrianco/the-goodies-swift

## Additional Resources

- [Swift Documentation](https://docs.swift.org)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Xcode User Guide](https://help.apple.com/xcode)
- [iOS Simulator User Guide](https://help.apple.com/simulator)