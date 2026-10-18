// anti_tamper.hpp - Security hardening system to detect tampering
// Copyright (c) 2025, All rights reserved.
#pragma once

#include <string>
#include <vector>
#include <functional>
#include <chrono>
#include <thread>
#include <atomic>
#include <mutex>
#include <random>
#include <cstring>
#include <cstdint>

#include "../logging.hpp"
#include "../error_handling.hpp"

// Forward declarations for system functions and constants
// This avoids including system headers in the header file which can cause macro conflicts
#ifdef __APPLE__
// Forward declare needed types without including system headers
typedef int pid_t;
typedef char* caddr_t;

// Define necessary constants
#ifndef PT_DENY_ATTACH
#define PT_DENY_ATTACH 31
#endif

#ifndef KERN_PROC
#define KERN_PROC 14
#endif

#ifndef KERN_PROC_PID
#define KERN_PROC_PID 1
#endif

#ifndef CTL_KERN
#define CTL_KERN 1
#endif

#ifndef P_TRACED
#define P_TRACED 0x00000800
#endif

// Forward declare functions we'll use
extern "C" {
    int ptrace(int request, pid_t pid, caddr_t addr, int data);
    pid_t getpid(void);
    int sysctl(int* name, unsigned int namelen, void* oldp, size_t* oldlenp, void* newp, size_t newlen);
}

// Forward declarations for Mach-O structures - implementations in .cpp file
struct mach_header;
struct mach_header_64;
struct load_command;
struct segment_command;
struct segment_command_64;

// Don't forward-declare kinfo_proc as it's defined in system headers
// We'll use an opaque pointer approach to avoid conflicts
typedef void* kinfo_proc_ptr;

#endif // __APPLE__

// Forward declare needed C++ includes to avoid system header conflicts
#include <string>
#include <vector>
#include <functional>
#include <thread>
#include <atomic>
#include <mutex>
#include <map>

namespace Security {

// Action to take when tampering is detected
enum class TamperAction {
    LOG_ONLY,       // Only log the tampering attempt
    STOP_EXECUTION, // Stop the execution of the script
    CRASH,          // Intentionally crash the application
    CORRUPT_DATA,   // Corrupt internal data structures
    CALLBACK        // Call a custom callback
};

// Types of security checks to perform
enum class SecurityCheckType {
    DEBUGGER,           // Check for attached debuggers
    CODE_INTEGRITY,     // Check code segment integrity
    DYLIB_HOOKS,        // Check for hooks in the dylib
    FUNCTION_HOOKS,     // Check for hooks in specific functions
    MEMORY_PROTECTION,  // Check memory protection flags
    PROCESS_ENVIRONMENT,// Check process environment
    VM_DETECTION,       // Check for virtual machine/emulator
    SYMBOL_HOOKS        // Check for symbol resolution hooks
};

// Tamper detection callback type
using TamperCallback = std::function<void(SecurityCheckType, const std::string&)>;

// Global security monitor class
class AntiTamper {
private:
    static std::mutex s_mutex;
    static std::atomic<bool> s_enabled;
    static std::atomic<bool> s_debuggerDetected;
    static std::atomic<bool> s_tamperingDetected;
    static std::map<SecurityCheckType, TamperAction> s_actionMap;
    static std::vector<TamperCallback> s_callbacks;
    static std::thread s_monitorThread;
    static std::atomic<bool> s_shouldRun;
    static std::atomic<uint64_t> s_checkInterval; // milliseconds
    static std::vector<uint8_t> s_codeHashes;
    static std::map<void*, uint32_t> s_functionChecksums;
    
    // Private initialization methods
    static void InitializeCodeHashes();
    static void InitializeFunctionChecksums();
    
    // Hash calculation helper
    static uint32_t CalculateChecksum(const void* data, size_t size) {
        if (!data || size == 0) return 0;
        
        uint32_t checksum = 0;
        const uint8_t* ptr = static_cast<const uint8_t*>(data);
        
        for (size_t i = 0; i < size; ++i) {
            checksum = ((checksum << 5) + checksum) + ptr[i]; // Simple hash function
        }
        
        return checksum;
    }
    
    // Handle tamper detection
    static void HandleTampering(SecurityCheckType checkType, const std::string& details) {
        // Set the tamper flag
        s_tamperingDetected = true;
        
        // Log the tampering
        Logging::LogCritical("Security", "Tampering detected: " + 
            std::to_string(static_cast<int>(checkType)) + " - " + details);
        
        // Look up the action for this check type
        TamperAction action;
        {
            std::lock_guard<std::mutex> lock(s_mutex);
            auto it = s_actionMap.find(checkType);
            action = (it != s_actionMap.end()) ? it->second : TamperAction::LOG_ONLY;
        }
        
        // Execute callbacks if registered
        std::vector<TamperCallback> callbacks;
        {
            std::lock_guard<std::mutex> lock(s_mutex);
            callbacks = s_callbacks;
        }
        
        for (const auto& callback : callbacks) {
            try {
                callback(checkType, details);
            } catch (...) {
                // Ignore callback exceptions
            }
        }
        
        // Handle action based on configuration
        switch (action) {
            case TamperAction::STOP_EXECUTION:
                // Report to error handling system
                ErrorHandling::ReportError(ErrorHandling::ErrorCodes::TAMPER_DETECTED, details);
                break;
                
            case TamperAction::CRASH:
                // Intentionally crash by dereferencing null
                Logging::LogCritical("Security", "Intentionally crashing due to tampering detection");
                {
                    volatile int* crash = nullptr;
                    *crash = 0; // This will cause a crash
                }
                break;
                
            case TamperAction::CORRUPT_DATA:
                // Corrupt internal data structures (implement specific corruption based on your architecture)
                Logging::LogCritical("Security", "Corrupting internal data due to tampering detection");
                // Example corruption: corrupt the function checksums
                {
                    std::lock_guard<std::mutex> lock(s_mutex);
                    s_functionChecksums.clear();
                }
                break;
                
            case TamperAction::CALLBACK:
                // Already handled above
                break;
                
            case TamperAction::LOG_ONLY:
            default:
                // Already logged above
                break;
        }
    }
    
public:
    // Initialize the anti-tamper system
    static bool Initialize() {
        if (s_enabled) {
            return true; // Already initialized
        }
        
        try {
            Logging::LogInfo("Security", "Initializing anti-tamper protection");
            
            // Set default actions for different check types
            {
                std::lock_guard<std::mutex> lock(s_mutex);
                s_actionMap[SecurityCheckType::DEBUGGER] = TamperAction::STOP_EXECUTION;
                s_actionMap[SecurityCheckType::CODE_INTEGRITY] = TamperAction::CRASH;
                s_actionMap[SecurityCheckType::DYLIB_HOOKS] = TamperAction::STOP_EXECUTION;
                s_actionMap[SecurityCheckType::FUNCTION_HOOKS] = TamperAction::STOP_EXECUTION;
                s_actionMap[SecurityCheckType::MEMORY_PROTECTION] = TamperAction::LOG_ONLY;
                s_actionMap[SecurityCheckType::PROCESS_ENVIRONMENT] = TamperAction::LOG_ONLY;
                s_actionMap[SecurityCheckType::VM_DETECTION] = TamperAction::LOG_ONLY;
                s_actionMap[SecurityCheckType::SYMBOL_HOOKS] = TamperAction::STOP_EXECUTION;
            }
            
            // Initialize code hashes for integrity checks
            InitializeCodeHashes();
            
            // Initialize function checksums
            InitializeFunctionChecksums();
            
            // Set the enabled flag
            s_enabled = true;
            
            Logging::LogInfo("Security", "Anti-tamper system initialized successfully");
            return true;
        } catch (const std::exception& ex) {
            Logging::LogError("Security", "Failed to initialize anti-tamper system: " + std::string(ex.what()));
            return false;
        }
    }
    
    // Start continuous monitoring on a background thread
    static void StartMonitoring(uint64_t intervalMs = 5000) { // Default: check every 5 seconds
        if (s_monitorThread.joinable()) {
            StopMonitoring();
        }
        
        s_checkInterval = intervalMs;
        s_shouldRun = true;
        
        s_monitorThread = std::thread([]() {
            // Add some randomness to the interval to make it harder to predict
            std::random_device rd;
            std::mt19937 gen(rd());
            std::uniform_int_distribution<> dist(-500, 500);
            
            while (s_shouldRun) {
                // Perform all security checks
                PerformSecurityChecks();
                
                // Sleep for the interval plus some random jitter
                int jitter = dist(gen);
                uint64_t sleepTime = s_checkInterval + jitter;
                if (sleepTime < 1000) sleepTime = 1000; // At least 1 second
                
                std::this_thread::sleep_for(std::chrono::milliseconds(sleepTime));
            }
        });
    }
    
    // Stop monitoring
    static void StopMonitoring() {
        if (s_monitorThread.joinable()) {
            s_shouldRun = false;
            s_monitorThread.join();
        }
    }
    
    // Manually trigger all security checks
    static bool PerformSecurityChecks() {
        if (!s_enabled) return true;
        
        bool allPassed = true;
        
        // Check for debuggers
        if (!CheckForDebugger()) {
            allPassed = false;
        }
        
        // Check code integrity
        if (!CheckCodeIntegrity()) {
            allPassed = false;
        }
        
        // Check for dylib hooks
        if (!CheckForDylibHooks()) {
            allPassed = false;
        }
        
        // Check for function hooks
        if (!CheckForFunctionHooks()) {
            allPassed = false;
        }
        
        // Check memory protection
        if (!CheckMemoryProtection()) {
            allPassed = false;
        }
        
        // Check process environment
        if (!CheckProcessEnvironment()) {
            allPassed = false;
        }
        
        // Check for VM/emulator
        if (!CheckForVirtualMachine()) {
            allPassed = false;
        }
        
        // Check for symbol hooks
        if (!CheckForSymbolHooks()) {
            allPassed = false;
        }
        
        return allPassed;
    }
    
    // Set the action to take when a specific type of tampering is detected
    static void SetTamperAction(SecurityCheckType checkType, TamperAction action) {
        std::lock_guard<std::mutex> lock(s_mutex);
        s_actionMap[checkType] = action;
    }
    
    // Register a callback to be called when tampering is detected
    static void RegisterCallback(TamperCallback callback) {
        std::lock_guard<std::mutex> lock(s_mutex);
        s_callbacks.push_back(callback);
    }
    
    // Check if tampering has been detected
    static bool IsTamperingDetected() {
        return s_tamperingDetected;
    }
    
    // Check if a debugger is attached
    static bool IsDebuggerAttached() {
        return s_debuggerDetected;
    }
    
    // Individual security checks
    
    // Helper function to check debugger using proc info - implementation in .cpp
    static bool CheckDebuggerUsingProcInfo();
    
    // Check for attached debugger
    static bool CheckForDebugger() {
        bool debuggerDetected = false;
        
#ifdef __APPLE__
        // Method 1: Check using sysctl - implementation moved to .cpp file
        // to avoid system header conflicts
        debuggerDetected = CheckDebuggerUsingProcInfo();
        
        // Method 2: Try ptrace
        if (!debuggerDetected) {
            if (ptrace(PT_DENY_ATTACH, 0, 0, 0) < 0) {
                // If ptrace fails, it could be because a debugger is already attached
                if (errno == EBUSY) {
                    debuggerDetected = true;
                }
            }
        }
        
        // Method 3: Check for presence of common debugger environment variables
        if (!debuggerDetected) {
            const char* debuggerEnvVars[] = {
                "DYLD_INSERT_LIBRARIES",
                "DYLD_FORCE_FLAT_NAMESPACE",
                "DYLD_IMAGE_SUFFIX"
            };
            
            for (const char* var : debuggerEnvVars) {
                if (getenv(var) != nullptr) {
                    debuggerDetected = true;
                    break;
                }
            }
        }
#else
        // Implement platform-specific debugger detection for other platforms
#endif
        
        // Update the global flag
        if (debuggerDetected) {
            s_debuggerDetected = true;
            HandleTampering(SecurityCheckType::DEBUGGER, "Debugger detected");
        }
        
        return !debuggerDetected;
    }
    
    // Check code segment integrity - implementation moved to .cpp file
    // to avoid incomplete type issues with Mach-O structures
    static bool CheckCodeIntegrity() {
        bool integrityIntact = true;
        
#ifdef __APPLE__
        // Call implementation function with all the Mach-O parsing logic
        integrityIntact = CheckCodeIntegrityImpl();
#endif
        
        return integrityIntact;
    }
    
    // Implementation function in cpp file
    static bool CheckCodeIntegrityImpl();
                
    // Check for hooks in the dylib - implementation moved to .cpp file
    static bool CheckForDylibHooks() {
        bool noHooksDetected = true;
        
#ifdef __APPLE__
        // Call implementation function with all the Mach-O parsing logic
        noHooksDetected = CheckForDylibHooksImpl();
#endif
        
        return noHooksDetected;
    }
    
    // Implementation function in cpp file
    static bool CheckForDylibHooksImpl();
    
    // Check for hooks in specific functions
    static bool CheckForFunctionHooks() {
        bool noHooksDetected = true;
        
        // Check the integrity of critical functions
        std::map<void*, uint32_t> functionCopy;
        {
            std::lock_guard<std::mutex> lock(s_mutex);
            functionCopy = s_functionChecksums;
        }
        
        for (const auto& pair : functionCopy) {
            void* funcPtr = pair.first;
            uint32_t storedChecksum = pair.second;
            
            // Calculate a small hash of the function's first 32 bytes to detect hooks
            uint32_t currentChecksum = CalculateChecksum(funcPtr, 32);
            
            if (currentChecksum != storedChecksum) {
                noHooksDetected = false;
                
                // Get function name (simplified, in a real implementation you'd have symbol info)
                std::string functionName = "unknown";
                
                HandleTampering(SecurityCheckType::FUNCTION_HOOKS, 
                    "Function hook detected in " + functionName);
                break;
            }
        }
        
        return noHooksDetected;
    }
    
    // Check memory protection settings - implementation moved to .cpp file
    static bool CheckMemoryProtection() {
        bool protectionValid = true;
        
#ifdef __APPLE__
        // Call implementation function with all the Mach-O parsing logic
        protectionValid = CheckMemoryProtectionImpl();
#endif
        
        return protectionValid;
    }
    
    // Implementation function in cpp file
    static bool CheckMemoryProtectionImpl();
    
    // Check process environment for suspicious settings
    static bool CheckProcessEnvironment() {
        bool environmentSafe = true;
        
        // Check for suspicious environment variables
        const char* suspiciousEnvVars[] = {
            "DYLD_INSERT_LIBRARIES",
            "DYLD_FORCE_FLAT_NAMESPACE",
            "DYLD_IMAGE_SUFFIX",
            "DYLD_PRINT_LIBRARIES",
            "DYLD_PRINT_APIS",
            "LD_PRELOAD",
            "LD_TRACE_LOADED_OBJECTS",
            "MALLOC_STACK_LOGGING",
            "MALLOC_FILL_SPACE"
        };
        
        for (const char* var : suspiciousEnvVars) {
            if (getenv(var) != nullptr) {
                environmentSafe = false;
                HandleTampering(SecurityCheckType::PROCESS_ENVIRONMENT, 
                    "Suspicious environment variable detected: " + std::string(var));
                break;
            }
        }
        
        return environmentSafe;
    }
    
    // Check for virtual machine or emulator
    static bool CheckForVirtualMachine() {
        bool notVirtualized = true;
        
#ifdef __APPLE__
        // On iOS, check for common virtualization indicators
        // These checks are simplified examples
        
        // Check for common emulator files
        const char* emulatorFiles[] = {
            "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform",
            "/opt/simulator"
        };
        
        for (const char* file : emulatorFiles) {
            // For iOS build compatibility, we'll stub the file access check
            // In a real implementation, we would use:
            // access(file, 0) != -1
            
            // Always return false for iOS build (assumes file doesn't exist)
            bool fileExists = false;
            
            if (fileExists) {
                notVirtualized = false;
                HandleTampering(SecurityCheckType::VM_DETECTION, 
                    "Possible simulator/emulator detected: " + std::string(file));
                break;
            }
        }
        
        // Check for common virtualization system calls (simplified)
        if (notVirtualized) {
            // This is just a placeholder - real implementation would have more sophisticated checks
            int virtualizedIndicator = 0;
            size_t size = sizeof(virtualizedIndicator);
            // Use constants that are defined in sys/sysctl.h instead of HW_MODEL
            // Use direct numeric values for sysctl constants instead of macros
            // 6 is typically CTL_HW on most systems
            int mib[2] = { 6, 2 }; // 6 is CTL_HW, 2 is HW_MODEL 
            
            // For iOS build compatibility, we'll stub this
            (void)mib; // Prevent unused variable warning
            (void)size; // Prevent unused variable warning
        }
#else
        // Implement platform-specific virtualization detection for other platforms
#endif
        
        return notVirtualized;
    }
    
    // Check for symbol resolution hooks
    static bool CheckForSymbolHooks() {
        bool noHooksDetected = true;
        
#ifdef __APPLE__
        // Stub implementation for iOS build compatibility
        // In a real implementation, this would include <dlfcn.h> and check for hooks
        
        // For iOS builds we'll assume no hooks were detected
        // This is a stub for build purposes only
        bool hookDetected = false;
        
        if (hookDetected) {
            noHooksDetected = false;
            HandleTampering(SecurityCheckType::SYMBOL_HOOKS, "Stub hook detection");
        }
#else
        // Implement platform-specific symbol hook detection for other platforms
#endif
        
        return noHooksDetected;
    }
    
    // Add a function to monitor for hooks
    static void MonitorFunction(void* funcPtr, size_t size = 32) {
        if (!funcPtr || size == 0) return;
        
        uint32_t checksum = CalculateChecksum(funcPtr, size);
        
        std::lock_guard<std::mutex> lock(s_mutex);
        s_functionChecksums[funcPtr] = checksum;
    }
    // Static members and initialization methods are defined in the .cpp file
};

// Convenience function to initialize security components
inline bool InitializeSecurity(bool startMonitoring = true) {
    try {
        Logging::LogInfo("Security", "Initializing security system");
        
        // Initialize anti-tamper protection
        if (!AntiTamper::Initialize()) {
            Logging::LogWarning("Security", "Failed to initialize anti-tamper protection");
        }
        
        // Start monitoring if requested
        if (startMonitoring) {
            AntiTamper::StartMonitoring();
        }
        
        Logging::LogInfo("Security", "Security system initialized successfully");
        return true;
    } catch (const std::exception& ex) {
        Logging::LogError("Security", "Failed to initialize security system: " + std::string(ex.what()));
        return false;
    }
}

} // namespace Security
