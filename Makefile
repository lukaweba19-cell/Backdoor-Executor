# Makefile for iOS Roblox Executor (cleaned & modular)
# No-JIT, iOS-only, SUNC/UNC aligned

.PHONY: all clean install directories info help

# Build type (Debug or Release)
BUILD_TYPE ?= Release

# iOS SDK settings (SDK resolved via xcrun when not passed)
ARCHS ?= arm64
MIN_IOS_VERSION ?= 15.0
SDK ?= $(shell xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)

ifeq ($(strip $(SDK)),)
$(error iPhoneOS SDK not found. Install Xcode or pass SDK=/path/to/iPhoneOS.sdk)
endif

# Feature flags
ENABLE_ADVANCED_BYPASS ?= 1
ENABLE_AI_FEATURES ?= 1
USE_DOBBY ?= 1

# Basic flags
ifeq ($(BUILD_TYPE),Debug)
	OPT_FLAGS := -g -O0
	DEFS := -DDEBUG_BUILD=1
else
	OPT_FLAGS := -O3
	DEFS := -DPRODUCTION_BUILD=1
endif

CXXFLAGS := -std=c++17 -fPIC $(OPT_FLAGS) -Wall -Wextra -fvisibility=hidden -ferror-limit=0
CFLAGS := -fPIC $(OPT_FLAGS) -Wall -Wextra -fvisibility=hidden -ferror-limit=0
OBJCXXFLAGS := -std=c++17 -fPIC $(OPT_FLAGS) -Wall -Wextra -fvisibility=hidden -ferror-limit=0
LDFLAGS := -shared -undefined dynamic_lookup \
	-framework Foundation -framework UIKit -framework CoreGraphics \
	-framework CoreFoundation -framework Security -framework CoreML -framework Vision

# Include paths (updated for modular layout)
INCLUDES := -I. -Ivm/include -Ivm/src -Ivm/src/Luau \
	-Icore -Ihooks -Iutils -Isecurity -Imemory -Iexec -Iios \
	-Iios/advanced_bypass -Iios/ui -Iios/ai_features -Iios/ai_features/vulnerability_detection \
	-Isecurity/anti_detection -Iutils/naming_conventions

# iOS SDK flags
PLATFORM_FLAGS := -isysroot $(SDK) -arch $(ARCHS) -mios-version-min=$(MIN_IOS_VERSION) \
	-DIOS_VERSION=$(MIN_IOS_VERSION) -DLUAU_PLATFORM_IOS=1 -DLUAU_TARGET_IOS=1 \
	-DNO_JIT=1 -DSUNC_COMPAT=1 -DUNC_COMPAT=1

# Output
BUILD_DIR := build
OUTPUT_DIR := output
LIB_NAME := libexecutor.dylib
INSTALL_DIR := /usr/local/lib

CXX := clang++
CC := clang
OBJCXX := clang++
LD := $(CXX) $(PLATFORM_FLAGS)

DOBBY_DIR ?= external/dobby
ifeq ($(USE_DOBBY),1)
	DEFS += -DUSE_DOBBY=1
	INCLUDES += -I$(DOBBY_DIR)/include
	LDFLAGS += -L$(DOBBY_DIR)/lib -ldobby
else
	DEFS += -DUSE_DOBBY=0
endif

ifeq ($(ENABLE_AI_FEATURES),1)
	DEFS += -DENABLE_AI_FEATURES=1
else
	DEFS += -DENABLE_AI_FEATURES=0
endif

ifeq ($(ENABLE_ADVANCED_BYPASS),1)
	DEFS += -DENABLE_ADVANCED_BYPASS=1
else
	DEFS += -DENABLE_ADVANCED_BYPASS=0
endif


# Source discovery (modular layout)
VM_SRC_DIR := vm/src
VM_SOURCES := $(shell find $(VM_SRC_DIR) -name "*.cpp" 2>/dev/null)

CORE_SOURCES := $(shell find core -maxdepth 1 -name "*.cpp" 2>/dev/null)
CORE_SOURCES := $(filter-out core/main.cpp,$(CORE_SOURCES))
HOOKS_SOURCES := $(shell find hooks -name "*.cpp" 2>/dev/null)
UTILS_SOURCES := $(shell find utils -name "*.cpp" 2>/dev/null)
SECURITY_SOURCES := $(shell find security -name "*.cpp" 2>/dev/null)
MEMORY_SOURCES := $(shell find memory -name "*.cpp" 2>/dev/null)
EXEC_SOURCES := $(shell find exec -name "*.cpp" 2>/dev/null)

iOS_CPP_SOURCES := $(shell find ios -name "*.cpp" 2>/dev/null)
iOS_CPP_SOURCES := $(filter-out %Statics.cpp,$(iOS_CPP_SOURCES))
iOS_MM_SOURCES := $(shell find ios -name "*.mm" 2>/dev/null)

ifeq ($(ENABLE_ADVANCED_BYPASS),0)
	iOS_CPP_SOURCES := $(filter-out ios/advanced_bypass/%,$(iOS_CPP_SOURCES))
	iOS_MM_SOURCES := $(filter-out ios/advanced_bypass/%,$(iOS_MM_SOURCES))
endif

ifeq ($(ENABLE_AI_FEATURES),0)
	iOS_CPP_SOURCES := $(filter-out ios/ai_features/%,$(iOS_CPP_SOURCES))
	iOS_MM_SOURCES := $(filter-out ios/ai_features/%,$(iOS_MM_SOURCES))
endif

# Objects
VM_OBJECTS := $(VM_SOURCES:.cpp=.o)
CORE_OBJECTS := $(CORE_SOURCES:.cpp=.o)
HOOKS_OBJECTS := $(HOOKS_SOURCES:.cpp=.o)
UTILS_OBJECTS := $(UTILS_SOURCES:.cpp=.o)
SECURITY_OBJECTS := $(SECURITY_SOURCES:.cpp=.o)
MEMORY_OBJECTS := $(MEMORY_SOURCES:.cpp=.o)
EXEC_OBJECTS := $(EXEC_SOURCES:.cpp=.o)
iOS_CPP_OBJECTS := $(iOS_CPP_SOURCES:.cpp=.o)
iOS_MM_OBJECTS := $(iOS_MM_SOURCES:.mm=.o)

OBJECTS := $(VM_OBJECTS) $(CORE_OBJECTS) $(HOOKS_OBJECTS) $(UTILS_OBJECTS) \
	$(SECURITY_OBJECTS) $(MEMORY_OBJECTS) $(EXEC_OBJECTS) \
	$(iOS_CPP_OBJECTS) $(iOS_MM_OBJECTS)

DYLIB_INSTALL_NAME := @executable_path/Frameworks/$(LIB_NAME)

all: directories $(OUTPUT_DIR)/$(LIB_NAME)

directories:
	@mkdir -p $(BUILD_DIR) $(OUTPUT_DIR)

clean:
	rm -rf $(OBJECTS) $(BUILD_DIR) $(OUTPUT_DIR)

install: all
	@mkdir -p $(INSTALL_DIR)
	cp $(OUTPUT_DIR)/$(LIB_NAME) $(INSTALL_DIR)/

$(OUTPUT_DIR)/$(LIB_NAME): $(OBJECTS)
	@echo "Linking $(LIB_NAME)..."
	@mkdir -p $(BUILD_DIR)
	$(LD) $(LDFLAGS) -o $@ $^ -install_name $(DYLIB_INSTALL_NAME)
	@echo "✅ Built $@"

%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) $(PLATFORM_FLAGS) $(DEFS) $(INCLUDES) -c -o $@ $<

%.o: %.mm
	@mkdir -p $(dir $@)
	$(OBJCXX) $(OBJCXXFLAGS) $(PLATFORM_FLAGS) $(DEFS) $(INCLUDES) -c -o $@ $<

%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(PLATFORM_FLAGS) $(DEFS) $(INCLUDES) -c -o $@ $<

info:
	@echo "Build Type: $(BUILD_TYPE)"
	@echo "Platform: iOS only (arm64)"
	@echo "No-JIT: enabled"
	@echo "SUNC/UNC: enabled"
	@echo "VM Sources: $(words $(VM_SOURCES))"
	@echo "Core Sources: $(words $(CORE_SOURCES))"
	@echo "iOS MM Sources: $(words $(iOS_MM_SOURCES))"
	@echo "Total Objects: $(words $(OBJECTS))"

help:
	@echo "Available targets:"
	@echo "  all     - Build the iOS .dylib (default)"
	@echo "  clean   - Remove build artifacts"
	@echo "  install - Install dylib"
	@echo "  info    - Print build information"
	@echo ""
	@echo "Variables:"
	@echo "  BUILD_TYPE=Debug|Release"
	@echo "  USE_DOBBY=0|1"
	@echo "  ENABLE_ADVANCED_BYPASS=0|1"
