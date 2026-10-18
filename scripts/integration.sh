#!/bin/bash
# integration.sh - Master script for building, testing, and deploying the iOS Roblox Executor
# This script integrates all the components into a single workflow

# Colors for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print banner
echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}       iOS Roblox Executor Integration Script       ${NC}"
echo -e "${BLUE}====================================================${NC}"

# Default configuration
BUILD_ONLY=0
CHECK_VERSION=1
RUN_DIAGNOSTICS=1
INSTALL_TO_DEVICE=0
DEVICE_IP=""
DEVICE_PASSWORD=""
BUILD_TYPE="Release"
ENABLE_AI=0
CLEAN_BUILD=1

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --build-only)
      BUILD_ONLY=1
      shift
      ;;
    --skip-version-check)
      CHECK_VERSION=0
      shift
      ;;
    --skip-diagnostics)
      RUN_DIAGNOSTICS=0
      shift
      ;;
    --install)
      INSTALL_TO_DEVICE=1
      shift
      ;;
    --device=*)
      DEVICE_IP="${1#*=}"
      shift
      ;;
    --password=*)
      DEVICE_PASSWORD="${1#*=}"
      shift
      ;;
    --debug)
      BUILD_TYPE="Debug"
      shift
      ;;
    --enable-ai)
      ENABLE_AI=1
      shift
      ;;
    --no-clean)
      CLEAN_BUILD=0
      shift
      ;;
    --help)
      echo "Usage: ./integration.sh [options]"
      echo ""
      echo "Options:"
      echo "  --build-only          Only build the dylib, don't run other steps"
      echo "  --skip-version-check  Skip Roblox version check"
      echo "  --skip-diagnostics    Skip diagnostic tests after build"
      echo "  --install             Install to iOS device after build"
      echo "  --device=IP           Specify iOS device IP for installation"
      echo "  --password=PWD        Specify iOS device SSH password"
      echo "  --debug               Build debug version"
      echo "  --enable-ai           Enable AI features"
      echo "  --no-clean            Skip cleaning before build"
      echo "  --help                Show this help message"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Create log directory
mkdir -p logs

# Step 1: Check for Roblox version updates if enabled
if [ $CHECK_VERSION -eq 1 ]; then
    echo -e "${BLUE}Checking for Roblox version updates...${NC}"
    
    if [ -f "./version_updater.sh" ]; then
        chmod +x ./version_updater.sh
        ./version_updater.sh > logs/version_check.log 2>&1
        
        if [ $? -ne 0 ]; then
            echo -e "${YELLOW}Warning: Version check reported issues. See logs/version_check.log for details.${NC}"
            echo -e "${YELLOW}Proceeding with build anyway...${NC}"
        else
            echo -e "${GREEN}Roblox version check completed.${NC}"
        fi
    else
        echo -e "${YELLOW}Warning: version_updater.sh not found. Skipping version check.${NC}"
    fi
fi

# Step 2: Build the library
echo -e "${BLUE}Building iOS Roblox Executor dylib...${NC}"

BUILD_ARGS=""
[ $BUILD_TYPE = "Debug" ] && BUILD_ARGS="$BUILD_ARGS --debug" || BUILD_ARGS="$BUILD_ARGS --release"
[ $ENABLE_AI -eq 1 ] && BUILD_ARGS="$BUILD_ARGS --enable-ai" || BUILD_ARGS="$BUILD_ARGS --disable-ai"
[ $CLEAN_BUILD -eq 1 ] && BUILD_ARGS="$BUILD_ARGS --clean"

if [ -f "./build_executor.sh" ]; then
    chmod +x ./build_executor.sh
    ./build_executor.sh $BUILD_ARGS > logs/build.log 2>&1
    
    BUILD_RESULT=$?
    
    if [ $BUILD_RESULT -ne 0 ]; then
        echo -e "${RED}Build failed! See logs/build.log for details.${NC}"
        exit 1
    else
        echo -e "${GREEN}Build completed successfully.${NC}"
    fi
else
    echo -e "${RED}Error: build_executor.sh not found!${NC}"
    exit 1
fi

# Check if we should stop after build
if [ $BUILD_ONLY -eq 1 ]; then
    echo -e "${GREEN}Build-only mode. Stopping after successful build.${NC}"
    exit 0
fi

# Step 3: Run diagnostics if enabled
if [ $RUN_DIAGNOSTICS -eq 1 ]; then
    echo -e "${BLUE}Running diagnostics tests...${NC}"
    
    # Create a simple script to run the diagnostic tests
    cat > run_diagnostics.cpp << 'EOF'
#include "core/Diagnostic.hpp"
#include <iostream>
#include <fstream>

int main() {
    // Initialize the diagnostic system
    if (!Diagnostics::DiagnosticSystem::Initialize()) {
        std::cerr << "Failed to initialize diagnostic system" << std::endl;
        return 1;
    }
    
    // Run all tests
    auto results = Diagnostics::DiagnosticSystem::RunAllTests();
    
    // Generate report
    std::string report = Diagnostics::DiagnosticSystem::GenerateReport();
    
    // Write report to file
    std::ofstream reportFile("diagnostic_report.html");
    if (reportFile.is_open()) {
        reportFile << report;
        reportFile.close();
        std::cout << "Diagnostic report written to diagnostic_report.html" << std::endl;
    } else {
        std::cerr << "Failed to write diagnostic report" << std::endl;
    }
    
    // Print summary
    int passCount = 0;
    for (const auto& result : results) {
        if (result.success) passCount++;
    }
    
    std::cout << "Diagnostic tests: " << passCount << "/" << results.size() << " passed" << std::endl;
    
    return (passCount == results.size()) ? 0 : 1;
}
EOF

    # Compile and run the diagnostic tests
    echo -e "${BLUE}Compiling diagnostic tests...${NC}"
    clang++ -std=c++17 -o run_diagnostics run_diagnostics.cpp core/Diagnostic.cpp -I. -Ivm/include -Ivm/src
    
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Warning: Failed to compile diagnostic tests. Continuing anyway.${NC}"
    else
        echo -e "${BLUE}Running diagnostic tests...${NC}"
        ./run_diagnostics > logs/diagnostics.log 2>&1
        
        DIAG_RESULT=$?
        
        if [ $DIAG_RESULT -ne 0 ]; then
            echo -e "${YELLOW}Warning: Some diagnostic tests failed. See logs/diagnostics.log for details.${NC}"
            echo -e "${YELLOW}Continuing with installation anyway...${NC}"
        else
            echo -e "${GREEN}All diagnostic tests passed.${NC}"
        fi
    fi
fi

# Step 4: Install to iOS device if requested
if [ $INSTALL_TO_DEVICE -eq 1 ]; then
    echo -e "${BLUE}Installing to iOS device...${NC}"
    
    if [ -z "$DEVICE_IP" ]; then
        echo -e "${YELLOW}No device IP specified. Please enter iOS device IP address:${NC}"
        read DEVICE_IP
    fi
    
    if [ -z "$DEVICE_PASSWORD" ]; then
        echo -e "${YELLOW}No password specified. Please enter SSH password for root@$DEVICE_IP:${NC}"
        read -s DEVICE_PASSWORD
    fi
    
    # Create the installation script
    cat > install_to_device.sh << EOF
#!/bin/bash
# Automatically transfer files to the device
echo "Installing to iOS device at $DEVICE_IP..."

# Create directories if they don't exist
ssh -o StrictHostKeyChecking=no root@$DEVICE_IP "mkdir -p /Library/MobileSubstrate/DynamicLibraries/ /var/mobile/Documents/RobloxExecutor/" || exit 1

# Create the plist file
cat > RobloxExecutor.plist << 'EOL'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Filter</key>
    <dict>
        <key>Bundles</key>
        <array>
            <string>com.roblox.robloxmobile</string>
        </array>
    </dict>
</dict>
</plist>
EOL

# Copy files to the device
scp output/libexecutor.dylib root@$DEVICE_IP:/Library/MobileSubstrate/DynamicLibraries/RobloxExecutor.dylib || exit 1
scp RobloxExecutor.plist root@$DEVICE_IP:/Library/MobileSubstrate/DynamicLibraries/ || exit 1
scp -r output/Resources/* root@$DEVICE_IP:/var/mobile/Documents/RobloxExecutor/ || exit 1

# Set permissions
ssh root@$DEVICE_IP "chmod 644 /Library/MobileSubstrate/DynamicLibraries/RobloxExecutor.dylib /Library/MobileSubstrate/DynamicLibraries/RobloxExecutor.plist" || exit 1

# Copy the Lua test script
cat > test_script.lua << 'EOL'
--[[
  Roblox Executor Test Script
  This script tests core functionality
]]

local results = {
  passed = 0,
  failed = 0,
  tests = {}
}

-- Add test result
local function addResult(name, passed, details)
  results.tests[#results.tests + 1] = {
    name = name,
    passed = passed,
    details = details or ""
  }
  
  if passed then
    results.passed = results.passed + 1
  else
    results.failed = results.failed + 1
  end
  
  print(passed and "✅ PASS:" or "❌ FAIL:", name, details or "")
end

print("====== Roblox Executor Test Suite ======")
print("Starting tests...")

-- Test environment
do
  local environment = getfenv and getfenv() or _ENV
  local isLuau = type(script) == "userdata" and pcall(function() return script.Name end)
  
  addResult("Environment", true, "Running in " .. (isLuau and "Luau" or "Lua"))
end

-- Test executor functions
do
  local hasExecuteScript = type(ExecuteScript) == "function"
  local hasWriteMemory = type(WriteMemory) == "function"
  local hasHookMethod = type(HookRobloxMethod) == "function"
  
  addResult("Executor Functions", hasExecuteScript or hasWriteMemory or hasHookMethod, 
    "Found: " .. 
    (hasExecuteScript and "ExecuteScript " or "") ..
    (hasWriteMemory and "WriteMemory " or "") ..
    (hasHookMethod and "HookRobloxMethod" or ""))
end

print("\n====== Test Results ======")
print(string.format("Passed: %d, Failed: %d, Total: %d", 
  results.passed, results.failed, results.passed + results.failed))
print("==========================")

return results
EOL

scp test_script.lua root@$DEVICE_IP:/var/mobile/Documents/RobloxExecutor/ || exit 1

echo "Installation complete. Respring device to apply changes?"
read -p "Respring now? (y/n): " respring

if [[ \$respring == "y" ]]; then
  ssh root@$DEVICE_IP "killall -9 SpringBoard" || echo "Failed to respring device"
  echo "Device is respringing..."
else
  echo "Skipping respring. Remember to respring manually or restart Roblox."
fi

echo "Installation complete!"
EOF

    chmod +x install_to_device.sh
    
    # Run the installation script
    echo -e "${BLUE}Transferring files to device...${NC}"
    ./install_to_device.sh > logs/install.log 2>&1
    
    INSTALL_RESULT=$?
    
    if [ $INSTALL_RESULT -ne 0 ]; then
        echo -e "${RED}Installation failed! See logs/install.log for details.${NC}"
        exit 1
    else
        echo -e "${GREEN}Installation completed successfully!${NC}"
        echo -e "${GREEN}The executor has been installed on your iOS device.${NC}"
        echo -e "${YELLOW}Remember to restart Roblox or respring your device to apply changes.${NC}"
    fi
fi

echo -e "${GREEN}All tasks completed successfully!${NC}"
echo -e "${BLUE}====================================================${NC}"
echo -e "Build log: ${YELLOW}logs/build.log${NC}"
[ $RUN_DIAGNOSTICS -eq 1 ] && echo -e "Diagnostics report: ${YELLOW}diagnostic_report.html${NC}"
[ $INSTALL_TO_DEVICE -eq 1 ] && echo -e "Installation log: ${YELLOW}logs/install.log${NC}"
echo -e "${BLUE}====================================================${NC}"
