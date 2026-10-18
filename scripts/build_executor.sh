#!/bin/bash
# build_executor.sh - Comprehensive build script for iOS Roblox Executor
# This script handles the complete build process for the dynamic library

# Colors for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
BUILD_TYPE="Release" # Can be Debug or Release
ENABLE_AI_FEATURES=0
ENABLE_ADVANCED_BYPASS=1
USE_DOBBY=1
CLEAN_BUILD=0
VERBOSE=0
INSTALL_DIR="./output"

# Print banner
echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}       Roblox Executor iOS Dylib Build Script       ${NC}"
echo -e "${BLUE}====================================================${NC}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --debug)
      BUILD_TYPE="Debug"
      shift
      ;;
    --release)
      BUILD_TYPE="Release"
      shift
      ;;
    --enable-ai)
      ENABLE_AI_FEATURES=1
      shift
      ;;
    --disable-ai)
      ENABLE_AI_FEATURES=0
      shift
      ;;
    --enable-bypass)
      ENABLE_ADVANCED_BYPASS=1
      shift
      ;;
    --disable-bypass)
      ENABLE_ADVANCED_BYPASS=0
      shift
      ;;
    --use-dobby)
      USE_DOBBY=1
      shift
      ;;
    --no-dobby)
      USE_DOBBY=0
      shift
      ;;
    --clean)
      CLEAN_BUILD=1
      shift
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    --install=*)
      INSTALL_DIR="${1#*=}"
      shift
      ;;
    --help)
      echo "Usage: ./build_executor.sh [options]"
      echo ""
      echo "Options:"
      echo "  --debug                Build with debugging enabled"
      echo "  --release              Build optimized release version (default)"
      echo "  --enable-ai            Enable AI features"
      echo "  --disable-ai           Disable AI features (default)"
      echo "  --enable-bypass        Enable advanced bypass (default)"
      echo "  --disable-bypass       Disable advanced bypass"
      echo "  --use-dobby            Use Dobby for hooking (default)"
      echo "  --no-dobby             Don't use Dobby"
      echo "  --clean                Clean before building"
      echo "  --verbose              Enable verbose output"
      echo "  --install=DIR          Set installation directory (default: ./output)"
      echo "  --help                 Show this help message"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Print configuration
echo -e "${BLUE}Build Configuration:${NC}"
echo -e "  Build Type: ${YELLOW}$BUILD_TYPE${NC}"
echo -e "  AI Features: ${YELLOW}$([ $ENABLE_AI_FEATURES -eq 1 ] && echo "Enabled" || echo "Disabled")${NC}"
echo -e "  Advanced Bypass: ${YELLOW}$([ $ENABLE_ADVANCED_BYPASS -eq 1 ] && echo "Enabled" || echo "Disabled")${NC}"
echo -e "  Use Dobby: ${YELLOW}$([ $USE_DOBBY -eq 1 ] && echo "Enabled" || echo "Disabled")${NC}"
echo -e "  Install Directory: ${YELLOW}$INSTALL_DIR${NC}"
echo ""

# Check for Xcode and iOS SDK
echo -e "${BLUE}Checking build environment...${NC}"

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: Xcode not found. Please install Xcode.${NC}"
    exit 1
fi

# Get iOS SDK path
IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)
if [ -z "$IOS_SDK" ]; then
    echo -e "${RED}Error: iOS SDK not found. Please install Xcode with iOS SDK.${NC}"
    exit 1
fi

SDK_VERSION=$(xcrun --sdk iphoneos --show-sdk-version 2>/dev/null)
echo -e "  Xcode: ${GREEN}✓${NC} ($(xcodebuild -version | head -n 1))"
echo -e "  iOS SDK: ${GREEN}✓${NC} (${SDK_VERSION} at ${IOS_SDK})"

# Check for required tools
REQUIRED_TOOLS=("clang++" "make" "git" "nm" "otool")
MISSING_TOOLS=0

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v $tool &> /dev/null; then
        echo -e "  $tool: ${RED}✗ Not found${NC}"
        MISSING_TOOLS=1
    else
        echo -e "  $tool: ${GREEN}✓${NC}"
    fi
done

if [ $MISSING_TOOLS -eq 1 ]; then
    echo -e "${RED}Error: Some required tools are missing. Please install them.${NC}"
    exit 1
fi

# Create directories
echo -e "${BLUE}Creating necessary directories...${NC}"
mkdir -p build
mkdir -p $INSTALL_DIR
mkdir -p $INSTALL_DIR/Resources/AIData

# Check Dobby dependency
echo -e "${BLUE}Checking for Dobby dependency...${NC}"
if [ $USE_DOBBY -eq 1 ]; then
    # Check if Dobby is in external directory
    if [ ! -d "external/dobby" ] || [ ! -f "external/dobby/lib/libdobby.a" ]; then
        echo -e "${YELLOW}Dobby not found in external/dobby. Attempting to build it...${NC}"
        
        # Create the directory
        mkdir -p external/dobby/include
        mkdir -p external/dobby/lib
        
        # Clone and build Dobby
        echo -e "${BLUE}Cloning and building Dobby...${NC}"
        git clone --depth=1 https://github.com/jmpews/Dobby.git temp_dobby
        pushd temp_dobby > /dev/null
        
        mkdir -p build
        cd build
        
        # Build Dobby static library
        cmake .. \
          -DCMAKE_BUILD_TYPE=Release \
          -DDOBBY_BUILD_SHARED_LIBRARY=OFF \
          -DDOBBY_BUILD_STATIC_LIBRARY=ON
        
        cmake --build . --config Release
        
        # Copy the results to external directory
        cp libdobby.a ../../external/dobby/lib/
        cp -r ../include/* ../../external/dobby/include/
        
        popd > /dev/null
        
        # Clean up
        rm -rf temp_dobby
        
        if [ -f "external/dobby/lib/libdobby.a" ]; then
            echo -e "${GREEN}Successfully built Dobby${NC}"
        else
            echo -e "${RED}Failed to build Dobby. Build will continue but may fail later.${NC}"
        fi
    else
        echo -e "${GREEN}Dobby found in external/dobby${NC}"
    fi
fi

# Clean build if requested
if [ $CLEAN_BUILD -eq 1 ]; then
    echo -e "${BLUE}Cleaning previous build...${NC}"
    make clean
    rm -rf build/*
fi

# Set environment variables for the build
export SDK=$(xcrun --sdk iphoneos --show-sdk-path)
export ARCHS="arm64"
export MIN_IOS_VERSION="15.0"
export BUILD_TYPE=$BUILD_TYPE
export ENABLE_AI_FEATURES=$ENABLE_AI_FEATURES
export ENABLE_ADVANCED_BYPASS=$ENABLE_ADVANCED_BYPASS
export USE_DOBBY=$USE_DOBBY

# Build the dynamic library
echo -e "${BLUE}Building the dynamic library...${NC}"
echo -e "  Running make with configuration: BUILD_TYPE=$BUILD_TYPE ENABLE_AI_FEATURES=$ENABLE_AI_FEATURES ENABLE_ADVANCED_BYPASS=$ENABLE_ADVANCED_BYPASS USE_DOBBY=$USE_DOBBY"

# Check VM folder structure
echo -e "${BLUE}Verifying VM folder structure...${NC}"
if [ -d "VM" ] && [ -d "vm/include" ] && [ -d "vm/src" ]; then
    VM_SRC_COUNT=$(find vm/src -name "*.cpp" | wc -l)
    VM_INCLUDE_COUNT=$(find vm/include -name "*.h" | wc -l)
    echo -e "  VM directory: ${GREEN}✓${NC} (Found $VM_SRC_COUNT source files and $VM_INCLUDE_COUNT headers)"
else
    echo -e "${RED}Error: VM folder structure is invalid. Make sure vm/include and vm/src exist.${NC}"
    exit 1
fi

# Ensure include folder is properly detected
echo -e "${BLUE}Checking include folder structure...${NC}"
if [ -d "include" ]; then
    INCLUDE_COUNT=$(find include -name "*.h" | wc -l)
    echo -e "  Include directory: ${GREEN}✓${NC} (Found $INCLUDE_COUNT headers)"
else
    echo -e "${YELLOW}Warning: include folder not found. This might lead to compilation errors.${NC}"
fi

# Run make with appropriate verbosity
if [ $VERBOSE -eq 1 ]; then
    make info
    make -j$(sysctl -n hw.ncpu) VERBOSE=1
else
    make -j$(sysctl -n hw.ncpu)
fi

# Check if build was successful
if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed! See above for errors.${NC}"
    exit 1
fi

# Install the dylib to the specified directory
echo -e "${BLUE}Installing to $INSTALL_DIR...${NC}"
make install INSTALL_DIR=$INSTALL_DIR

# Create default configuration if needed
if [ ! -f "$INSTALL_DIR/Resources/AIData/config.json" ]; then
    echo -e "${BLUE}Creating default configuration...${NC}"
    echo '{"version":"1.0.0","led_effects":true,"ai_features":'$([ $ENABLE_AI_FEATURES -eq 1 ] && echo "true" || echo "false")',"memory_optimization":true,"advanced_bypass":'$([ $ENABLE_ADVANCED_BYPASS -eq 1 ] && echo "true" || echo "false")'}' > $INSTALL_DIR/Resources/AIData/config.json
fi

# Verify the built library
echo -e "${BLUE}Verifying built library...${NC}"
if [ -f "$INSTALL_DIR/libexecutor.dylib" ]; then
    # Get file info
    echo -e "  File size: $(du -h "$INSTALL_DIR/libexecutor.dylib" | cut -f1)"
    echo -e "  File type: $(file "$INSTALL_DIR/libexecutor.dylib" | cut -d':' -f2)"
    
    # Check for key symbols
    echo -e "  Checking for key exported symbols..."
    if nm -g "$INSTALL_DIR/libexecutor.dylib" | grep -q 'luaopen_mylibrary'; then
        echo -e "    - luaopen_mylibrary: ${GREEN}✓${NC}"
    else
        echo -e "    - luaopen_mylibrary: ${RED}✗ Not found${NC}"
    fi
    
    if nm -g "$INSTALL_DIR/libexecutor.dylib" | grep -q 'ExecuteScript'; then
        echo -e "    - ExecuteScript: ${GREEN}✓${NC}"
    else
        echo -e "    - ExecuteScript: ${RED}✗ Not found${NC}"
    fi
    
    if nm -g "$INSTALL_DIR/libexecutor.dylib" | grep -q 'dylib_initializer'; then
        echo -e "    - dylib_initializer: ${GREEN}✓${NC}"
    else
        echo -e "    - dylib_initializer: ${RED}✗ Not found${NC}"
    fi
    
    # Show dependencies
    echo -e "  Library dependencies:"
    otool -L "$INSTALL_DIR/libexecutor.dylib" | tail -n +2 | while read -r line; do
        echo -e "    - $(echo $line | sed 's/^[[:space:]]*//')"
    done
    
    echo -e "${GREEN}Build completed successfully!${NC}"
    echo -e "Library installed to: ${YELLOW}$INSTALL_DIR/libexecutor.dylib${NC}"
else
    echo -e "${RED}Library not found after build! Check for errors above.${NC}"
    exit 1
fi
