#pragma once

#include <cstdint>
#include <string>
#include <vector>
#include <mutex>
#include <unordered_map>
#include <atomic>
#include <thread>
#include <chrono>
#include <mach-o/dyld.h>
#include <dlfcn.h>
#include <sys/sysctl.h>
#include <sys/stat.h>

// Objective-C headers needed for iOS functionality
#include <objc/objc.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <objc/NSObjCRuntime.h>

// Include Lua headers through our wrapper to avoid macro redefinitions
#include "luadefs_wrapper.h"

#include "memory/signature.hpp"
#include "memory/ci_compat.h"
#include "logging.hpp"

// Global variables for Roblox context
static std::uintptr_t ScriptContext{};  // Roblox's scriptcontext
static lua_State* rL{};                 // Roblox's lstate
static lua_State* eL{};                 // Exploit's lstate

// Address cache with versioning to handle Roblox updates
class AddressCache {
private:
    static std::mutex cacheMutex;
    static std::string currentRobloxVersion;
    static std::unordered_map<std::string, uintptr_t> addressCache;
    static std::unordered_map<std::string, std::string> signatureMap;
    static std::atomic<bool> isCacheInitialized;
    static std::atomic<bool> isVersionCheckInProgress;
    
    // Pattern signatures for dynamic scanning - iOS ARM64 specific patterns
    // These ARM64 patterns are compatible with iOS Roblox builds
    static void InitializeSignatures() {
        std::lock_guard<std::mutex> lock(cacheMutex);
        
        if (signatureMap.empty()) {
            // ARM64 patterns for iOS Roblox
            signatureMap["startscript"] = "FF 83 00 D1 FA 67 01 A9 F8 5F 02 A9 F6 57 03 A9 F4 4F 04 A9";
            signatureMap["getstate"] = "FF 43 00 D1 F3 03 00 AA FD 7B 01 A9 FD 03 00 91 13 00 40 F9";
            signatureMap["newthread"] = "F3 03 00 AA FD 7B 01 A9 FD 03 00 91 13 00 40 F9 1F 01 00 F1";
            signatureMap["luauload"] = "FF C3 00 D1 F6 57 01 A9 F4 4F 02 A9 FD 7B 03 A9 FD 03 00 91";
            signatureMap["spawn"] = "FF 83 01 D1 F6 57 01 A9 F4 4F 02 A9 FD 7B 03 A9 FD 03 00 91";
            
            // Add more specific iOS signatures based on version
            signatureMap["startscript_2023"] = "FD 7B BF A9 FD 03 00 91 FF 43 00 D1 F3 03 00 AA";
            signatureMap["getstate_2023"] = "FF 43 00 D1 F3 03 01 AA F4 03 00 AA FD 7B 01 A9";
            signatureMap["newthread_2023"] = "F4 03 01 AA FD 7B BF A9 FD 03 00 91 F3 03 00 AA";
            signatureMap["luauload_2023"] = "FF 43 01 D1 F5 13 00 F9 F3 13 01 F9 FD 7B 03 A9";
            signatureMap["spawn_2023"] = "FF 43 00 D1 F9 63 01 A9 F7 5B 02 A9 F5 53 03 A9";
        }
    }
    
    // Fallback addresses for iOS - these are adjusted based on recent iOS builds
    // These are specifically for the latest Roblox iOS build as of 2025-04
    static const uintptr_t FALLBACK_iOS_STARTSCRIPT = 0x1008D7E24;
    static const uintptr_t FALLBACK_iOS_GETSTATE = 0x1008E1A3C;
    static const uintptr_t FALLBACK_iOS_NEWTHREAD = 0x1008F2D14;
    static const uintptr_t FALLBACK_iOS_LUAULOAD = 0x1008F5E28;
    static const uintptr_t FALLBACK_iOS_SPAWN = 0x10093AEC0;
    
    // Helper function to check if a file exists
    static bool FileExists(const std::string& path) {
        struct stat buffer;
        return (stat(path.c_str(), &buffer) == 0);
    }
    
    // Helper functions for safer Objective-C messaging
    static id objc_msgSend_id(id target, SEL selector) {
        typedef id (*MsgSendIdType)(id, SEL);
        MsgSendIdType msgSend = (MsgSendIdType)dlsym(RTLD_DEFAULT, "objc_msgSend");
        if (msgSend) {
            return msgSend(target, selector);
        }
        return nil;
    }
    
    static id objc_msgSend_id_id(id target, SEL selector, id arg) {
        typedef id (*MsgSendIdIdType)(id, SEL, id);
        MsgSendIdIdType msgSend = (MsgSendIdIdType)dlsym(RTLD_DEFAULT, "objc_msgSend");
        if (msgSend) {
            return msgSend(target, selector, arg);
        }
        return nil;
    }
    
    static id objc_msgSend_id_cstr(id target, SEL selector, const char* arg) {
        typedef id (*MsgSendIdCstrType)(id, SEL, const char*);
        MsgSendIdCstrType msgSend = (MsgSendIdCstrType)dlsym(RTLD_DEFAULT, "objc_msgSend");
        if (msgSend) {
            return msgSend(target, selector, arg);
        }
        return nil;
    }
    
    static const char* objc_msgSend_cstr(id target, SEL selector) {
        typedef const char* (*MsgSendCstrType)(id, SEL);
        MsgSendCstrType msgSend = (MsgSendCstrType)dlsym(RTLD_DEFAULT, "objc_msgSend");
        if (msgSend) {
            return msgSend(target, selector);
        }
        return nullptr;
    }
    
    // Dynamic function to extract iOS app bundle version
    static std::string GetIOSAppVersion() {
        // Try to get version from app bundle first
        Class nsBundle = objc_getClass("NSBundle");
        if (nsBundle) {
            id mainBundle = objc_msgSend_id((id)nsBundle, sel_registerName("mainBundle"));
            if (mainBundle) {
                id infoDictionary = objc_msgSend_id(mainBundle, sel_registerName("infoDictionary"));
                if (infoDictionary) {
                    Class nsStringClass = objc_getClass("NSString");
                    id versionKey = objc_msgSend_id_cstr(
                        (id)nsStringClass, 
                        sel_registerName("stringWithUTF8String:"), 
                        "CFBundleShortVersionString"
                    );
                    
                    id versionObj = objc_msgSend_id_id(
                        infoDictionary, 
                        sel_registerName("objectForKey:"), 
                        versionKey
                    );
                    
                    if (versionObj) {
                        const char* versionCStr = objc_msgSend_cstr(
                            versionObj, 
                            sel_registerName("UTF8String")
                        );
                        if (versionCStr) {
                            return std::string(versionCStr);
                        }
                    }
                }
            }
        }
        
        // Fallback: Use binary modification date as a version approximation
        uint32_t count = _dyld_image_count();
        for (uint32_t i = 0; i < count; ++i) {
            const char* imageName = _dyld_get_image_name(i);
            if (imageName && strstr(imageName, "RobloxPlayer") != nullptr) {
                struct stat st;
                if (stat(imageName, &st) == 0) {
                    // Use modification time as a version proxy
                    char timeBuf[32];
                    strftime(timeBuf, sizeof(timeBuf), "%Y%m%d", localtime(&st.st_mtime));
                    return std::string("iOS_") + timeBuf;
                }
            }
        }
        
        // Last resort fallback
        return "iOS_Unknown";
    }
    
public:
    // Initialize the address cache
    static void Initialize() {
        if (!isCacheInitialized) {
            InitializeSignatures();
            currentRobloxVersion = GetRobloxVersion();
            isCacheInitialized = true;
            
            Logging::LogInfo("AddressCache", "Initialized with Roblox version: " + currentRobloxVersion);
        }
    }
    
    // Detect current Roblox version for iOS
    static std::string GetRobloxVersion() {
        // Prevent concurrent version checks
        if (isVersionCheckInProgress) {
            return currentRobloxVersion.empty() ? "iOS_Unknown" : currentRobloxVersion;
        }
        
        isVersionCheckInProgress = true;
        
        std::string version = GetIOSAppVersion();
        
        // Version check completed
        isVersionCheckInProgress = false;
        
        return version;
    }
    
    // Reset the cache when Roblox updates
    static void ResetCache() {
        std::lock_guard<std::mutex> lock(cacheMutex);
        addressCache.clear();
        currentRobloxVersion = GetRobloxVersion();
        
        Logging::LogInfo("AddressCache", "Cache reset. New Roblox version: " + currentRobloxVersion);
    }
    
    // Get module base address for iOS
    static uintptr_t GetRobloxBaseAddress() {
        uint32_t count = _dyld_image_count();
        for (uint32_t i = 0; i < count; ++i) {
            const char* imageName = _dyld_get_image_name(i);
            if (imageName && strstr(imageName, "RobloxPlayer") != nullptr) {
                return (uintptr_t)_dyld_get_image_header(i);
            }
        }
        return 0;
    }
    
    // Get an address either from cache or by scanning
    static uintptr_t GetAddress(const std::string& name) {
        // Initialize if needed
        if (!isCacheInitialized) {
            Initialize();
        }
        
        // Check if Roblox has updated
        std::string version = GetRobloxVersion();
        if (version != currentRobloxVersion && !currentRobloxVersion.empty()) {
            ResetCache();
        }
        
        // Check if address is in cache
        {
            std::lock_guard<std::mutex> lock(cacheMutex);
            auto it = addressCache.find(name);
            if (it != addressCache.end()) {
                return it->second;
            }
        }
        
        // Not in cache, need to scan for it
        uintptr_t address = 0;
        
        // Use pattern scanning with year-specific signatures if available
        std::string yearSpecificName = name + "_" + version.substr(0, 4);
        
        Logging::LogInfo("AddressCache", "Scanning for " + name + " (version: " + version + ")");
        
        // Try version-specific pattern first
        std::string pattern;
        {
            std::lock_guard<std::mutex> lock(cacheMutex);
            auto it = signatureMap.find(yearSpecificName);
            if (it != signatureMap.end()) {
                pattern = it->second;
            } else {
                // Fall back to generic pattern
                auto genIt = signatureMap.find(name);
                if (genIt != signatureMap.end()) {
                    pattern = genIt->second;
                }
            }
        }
        
        if (!pattern.empty()) {
            address = Memory::PatternScanner::ScanForSignature(pattern).address;
            
            if (address != 0) {
                Logging::LogInfo("AddressCache", "Found " + name + " at 0x" + 
                               std::to_string(address) + " via pattern scan");
            }
        }
        
        // If scan failed, use fallback address
        if (address == 0) {
            // Get base address to adjust fallbacks
            uintptr_t baseAddr = GetRobloxBaseAddress();
            
            if (name == "startscript") {
                address = baseAddr ? (baseAddr + FALLBACK_iOS_STARTSCRIPT - 0x100000000) : FALLBACK_iOS_STARTSCRIPT;
            } else if (name == "getstate") {
                address = baseAddr ? (baseAddr + FALLBACK_iOS_GETSTATE - 0x100000000) : FALLBACK_iOS_GETSTATE;
            } else if (name == "newthread") {
                address = baseAddr ? (baseAddr + FALLBACK_iOS_NEWTHREAD - 0x100000000) : FALLBACK_iOS_NEWTHREAD;
            } else if (name == "luauload") {
                address = baseAddr ? (baseAddr + FALLBACK_iOS_LUAULOAD - 0x100000000) : FALLBACK_iOS_LUAULOAD;
            } else if (name == "spawn") {
                address = baseAddr ? (baseAddr + FALLBACK_iOS_SPAWN - 0x100000000) : FALLBACK_iOS_SPAWN;
            }
            
            if (address != 0) {
                Logging::LogInfo("AddressCache", "Using fallback address for " + name + ": 0x" + 
                               std::to_string(address));
            }
        }
        
        // Cache the result
        if (address != 0) {
            std::lock_guard<std::mutex> lock(cacheMutex);
            addressCache[name] = address;
        } else {
            Logging::LogError("AddressCache", "Failed to find address for " + name);
        }
        
        return address;
    }
};

// Initialize static members
std::mutex AddressCache::cacheMutex;
std::string AddressCache::currentRobloxVersion = "";
std::unordered_map<std::string, uintptr_t> AddressCache::addressCache;
std::unordered_map<std::string, std::string> AddressCache::signatureMap;
std::atomic<bool> AddressCache::isCacheInitialized(false);
std::atomic<bool> AddressCache::isVersionCheckInProgress(false);

// Function to get addresses - replace direct access with this
inline uintptr_t GetFunctionAddress(const std::string& name) {
    return AddressCache::GetAddress(name);
}

// Convenience definitions for commonly used addresses
#define startscript_addy GetFunctionAddress("startscript")
#define getstate_addy GetFunctionAddress("getstate")
#define newthread_addy GetFunctionAddress("newthread")
#define luauload_addy GetFunctionAddress("luauload")
#define spawn_addy GetFunctionAddress("spawn")

// Configuration for the executor - optimized for iOS
namespace ExecutorConfig {
    // Whether to enable advanced anti-detection features
    static bool EnableAntiDetection = true;
    
    // Whether to enable script obfuscation for outgoing scripts
    static bool EnableScriptObfuscation = true;
    
    // Whether to enable VM detection countermeasures
    static bool EnableVMDetection = true;
    
    // Whether to encrypt stored scripts
    static bool EncryptSavedScripts = true;
    
    // Script execution timeout in milliseconds (0 = no timeout)
    static int ScriptExecutionTimeout = 5000;
    
    // Auto-retry on failed execution
    static bool AutoRetryFailedExecution = true;
    static int MaxAutoRetries = 3;
    
    // iOS-specific options
    namespace iOS {
        // Memory usage settings
        static int MemoryLimitMB = 256;  // Limit memory usage to avoid watchdog termination
        
        // UI Configuration
        static bool UseFloatingButton = true;
        static bool AutoHideUIInScreenshots = true;
        
        // Battery optimization
        static bool EnableBatteryOptimization = true;
        
        // Network settings
        static bool UseSecureConnections = true;
        static bool BlockTeleportRequests = false;  // Will be user-configurable
        
        // Stability settings
        static bool CrashRecoveryEnabled = true;
        static int BackgroundTimeout = 30;  // Seconds before cleaning up when app goes to background
    }
    
    // Advanced execution options
    namespace Advanced {
        // Cache compiled scripts to improve performance
        static bool EnableScriptCaching = true;
        
        // Enable self-modification capabilities for anti-detection
        static bool EnableSelfModification = true;
        
        // Bypass specific checks
        static bool BypassJailbreakDetection = true;
        static bool BypassIntegrityChecks = true;
        
        // Security options
        static bool ObfuscateInternalFunctions = true;
        static bool RandomizeMemoryLayout = true;
        
        // Debug options - disabled in production
        static bool EnableDebugLogs = false;
    }
}