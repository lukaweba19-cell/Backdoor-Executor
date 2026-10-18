#include "TeleportControl.h"
#include "MemoryAccess.h"
#include "../security/anti_tamper.hpp"
#include "../anti_detection/anti_debug.hpp"
#include "../dobby_wrapper.cpp"

#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <dlfcn.h>
#include <objc/runtime.h>
#include <objc/message.h>

// Required Objective-C imports
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

namespace iOS {
    // Original teleport function type definition
    typedef bool (*TeleportFunc)(void* teleportService, int teleportType, const char* placeId, 
                                void* instanceId, void* teleportData, bool* success);
    
    // Original validation function type definition
    typedef bool (*ValidationFunc)(void* teleportService, const char* placeId, void* requestData);
    
    // Static instance for singleton
    static TeleportControl* s_instance = nullptr;
    
    // Hook function for teleport interception
    static bool TeleportHookFunction(void* teleportService, int teleportType, const char* placeId, 
                                    void* instanceId, void* teleportData, bool* success) {
        // Get original function
        TeleportFunc originalFunc = (TeleportFunc)TeleportControl::GetInstance().m_originalTeleportFunc;
        if (!originalFunc) {
            Logging::LogError("TeleportControl", "Original teleport function is null");
            return false;
        }
        
        // Get destination from teleport data if available
        std::string destination = "Unknown";
        if (teleportData) {
            // Extract destination from teleport data structure
            // TeleportData structure varies by Roblox version, so we need to access it carefully
            try {
                void** teleportDataPtr = (void**)teleportData;
                if (teleportDataPtr && teleportDataPtr[1]) {
                    const char* destCStr = (const char*)teleportDataPtr[1];
                    if (destCStr) {
                        destination = destCStr;
                    }
                }
            } catch (...) {
                // Safely handle any memory access issues
                Logging::LogWarning("TeleportControl", "Failed to extract destination from teleport data");
            }
        }
        
        // Convert teleport type to our enum
        TeleportControl::TeleportType tpType = TeleportControl::TeleportType::ServerTeleport;
        switch (teleportType) {
            case 0:
                tpType = TeleportControl::TeleportType::ServerTeleport;
                break;
            case 1:
                tpType = TeleportControl::TeleportType::GameTeleport;
                break;
            case 2:
                tpType = TeleportControl::TeleportType::PrivateServerTeleport;
                break;
            case 3:
                tpType = TeleportControl::TeleportType::ReservedServerTeleport;
                break;
            case 4:
                tpType = TeleportControl::TeleportType::FriendTeleport;
                break;
            case 5:
                tpType = TeleportControl::TeleportType::ExtensionTeleport;
                break;
        }
        
        std::string placeIdStr = placeId ? placeId : "Unknown";
        
        // Process teleport request
        bool shouldProceed = TeleportControl::GetInstance().ProcessTeleportRequest(
            tpType, destination, placeIdStr);
        
        if (!shouldProceed) {
            // Log blocked teleport
            Logging::LogInfo("TeleportControl", "Blocked teleport to " + destination + 
                           " (PlaceId: " + placeIdStr + ")");
            
            // Set success to true to avoid game errors, but don't actually teleport
            if (success) {
                *success = true;
            }
            
            // Return true to indicate "success" to the game
            return true;
        }
        
        // Allow the teleport by calling the original function
        Logging::LogInfo("TeleportControl", "Allowing teleport to " + destination + 
                       " (PlaceId: " + placeIdStr + ")");
        
        // Call original function
        return originalFunc(teleportService, teleportType, placeId, instanceId, teleportData, success);
    }
    
    // Hook function for validation bypass
    static bool ValidationHookFunction(void* teleportService, const char* placeId, void* requestData) {
        // Get original function
        ValidationFunc originalFunc = (ValidationFunc)TeleportControl::GetInstance().m_originalValidationFunc;
        if (!originalFunc) {
            Logging::LogError("TeleportControl", "Original validation function is null");
            return true; // Return success to avoid errors
        }
        
        // Always modify request fingerprints to match server-initiated teleports
        if (requestData) {
            TeleportControl::GetInstance().ModifyTeleportFingerprint(requestData);
        }
        
        // Call original function or bypass entirely based on settings
        if (ExecutorConfig::Advanced::BypassIntegrityChecks) {
            // Bypass validation entirely
            Logging::LogInfo("TeleportControl", "Bypassing teleport validation for PlaceId: " + 
                            std::string(placeId ? placeId : "Unknown"));
            return true;
        } else {
            // Call original but with modified request data
            return originalFunc(teleportService, placeId, requestData);
        }
    }
    
    // TeleportControl implementation
    TeleportControl& TeleportControl::GetInstance() {
        if (!s_instance) {
            s_instance = new TeleportControl();
        }
        return *s_instance;
    }
    
    TeleportControl::TeleportControl() 
        : m_initialized(false), 
          m_controlMode(ControlMode::AllowAll) {
        
        // Initialize static members - moved out of initialization list
        if (m_teleportHook == nullptr) {
            m_teleportHook = nullptr;
            m_teleportValidationHook = nullptr;
            m_originalTeleportFunc = nullptr;
            m_originalValidationFunc = nullptr;
        }
        
        // Setup default custom rules
        m_customRules[TeleportType::ServerTeleport] = true;
        m_customRules[TeleportType::GameTeleport] = false;
        m_customRules[TeleportType::PrivateServerTeleport] = true;
        m_customRules[TeleportType::ReservedServerTeleport] = true;
        m_customRules[TeleportType::FriendTeleport] = true;
        m_customRules[TeleportType::ExtensionTeleport] = false;
    }
    
    bool TeleportControl::Initialize() {
        if (m_initialized) {
            return true;
        }
        
        Logging::LogInfo("TeleportControl", "Initializing teleport control system");
        
        // Apply anti-debugging measures before hooking
        AntiDetection::AntiDebug::ApplyAntiTamperingMeasures();
        
        // Find and hook teleport functions
        bool hookSuccess = HookTeleportService() && BypassTeleportValidation();
        
        if (hookSuccess) {
            m_initialized = true;
            Logging::LogInfo("TeleportControl", "Teleport control system initialized successfully");
        } else {
            Logging::LogError("TeleportControl", "Failed to initialize teleport control system");
        }
        
        return m_initialized;
    }
    
    void TeleportControl::Shutdown() {
        std::lock_guard<std::mutex> lock(m_mutex);
        
        if (m_teleportHook && m_originalTeleportFunc) {
            // Unhook teleport function
            Hooks::Implementation::UnhookFunction(m_teleportHook);
            m_teleportHook = nullptr;
        }
        
        if (m_teleportValidationHook && m_originalValidationFunc) {
            // Unhook validation function
            Hooks::Implementation::UnhookFunction(m_teleportValidationHook);
            m_teleportValidationHook = nullptr;
        }
        
        m_initialized = false;
        
        Logging::LogInfo("TeleportControl", "Teleport control system shutdown");
    }
    
    void TeleportControl::SetControlMode(ControlMode mode) {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_controlMode = mode;
        
        Logging::LogInfo("TeleportControl", "Teleport control mode set to: " + std::to_string(static_cast<int>(mode)));
    }
    
    TeleportControl::ControlMode TeleportControl::GetControlMode() const {
        std::lock_guard<std::mutex> lock(m_mutex);
        return m_controlMode;
    }
    
    void TeleportControl::SetCustomRule(TeleportType type, bool allow) {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_customRules[type] = allow;
        
        Logging::LogInfo("TeleportControl", "Custom rule set: TeleportType " + 
                        std::to_string(static_cast<int>(type)) + " = " + (allow ? "Allow" : "Block"));
    }
    
    void TeleportControl::RegisterCallback(TeleportCallback callback) {
        if (!callback) {
            return;
        }
        
        std::lock_guard<std::mutex> lock(m_mutex);
        m_callbacks.push_back(callback);
    }
    
    bool TeleportControl::ProcessTeleportRequest(TeleportType type, const std::string& destination, 
                                               const std::string& placeId) {
        // Store last teleport info
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            m_lastDestination = destination;
            m_lastPlaceId = placeId;
        }
        
        // Process based on control mode
        switch (m_controlMode) {
            case ControlMode::AllowAll:
                return true;
                
            case ControlMode::BlockAll:
                return false;
                
            case ControlMode::PromptUser: {
                // Call all callbacks and wait for user decision
                std::vector<TeleportCallback> callbacks;
                {
                    std::lock_guard<std::mutex> lock(m_mutex);
                    callbacks = m_callbacks;
                }
                
                for (const auto& callback : callbacks) {
                    if (!callback(type, destination, placeId)) {
                        return false; // Any callback can block the teleport
                    }
                }
                
                // If no callbacks or all callbacks returned true, allow the teleport
                return true;
            }
                
            case ControlMode::CustomRules: {
                std::lock_guard<std::mutex> lock(m_mutex);
                auto it = m_customRules.find(type);
                if (it != m_customRules.end()) {
                    return it->second;
                }
                return true; // Default to allow if no rule set
            }
                
            default:
                return true;
        }
    }
    
    std::pair<std::string, std::string> TeleportControl::GetLastTeleportInfo() const {
        std::lock_guard<std::mutex> lock(m_mutex);
        return {m_lastDestination, m_lastPlaceId};
    }
    
    bool TeleportControl::HookTeleportService() {
        // Find teleport functions in memory
        if (!FindTeleportFunctions()) {
            Logging::LogError("TeleportControl", "Failed to find teleport functions");
            return false;
        }
        
        // Hook the teleport function
        if (m_originalTeleportFunc) {
            void* hookAddr = nullptr;
            bool success = Hooks::Implementation::HookFunction(
                m_originalTeleportFunc, 
                (void*)TeleportHookFunction, 
                &hookAddr);
            
            if (success && hookAddr) {
                m_teleportHook = m_originalTeleportFunc;
                Logging::LogInfo("TeleportControl", "Successfully hooked teleport function");
                return true;
            } else {
                Logging::LogError("TeleportControl", "Failed to hook teleport function");
            }
        }
        
        return false;
    }
    
    bool TeleportControl::FindTeleportFunctions() {
        // First try to find through pattern scanning
        try {
            // Teleport function pattern for iOS ARM64
            const char* teleportPattern = "FF C3 01 D1 FB 03 00 AA F9 5B 01 A9 FA 67 02 A9 F8 5F 03 A9 F6 57 04 A9";
            
            // Validation function pattern for iOS ARM64
            const char* validationPattern = "FF 83 00 D1 FA 67 01 A9 F8 5F 02 A9 F6 57 03 A9 F4 4F 04 A9 FD 7B 05 A9";
            
            // Scan for the patterns
            auto teleportResult = Memory::PatternScanner::ScanForSignature(teleportPattern);
            if (teleportResult) {
                m_originalTeleportFunc = teleportResult.As<void>();
                Logging::LogInfo("TeleportControl", "Found teleport function at: " + 
                               std::to_string(reinterpret_cast<uintptr_t>(m_originalTeleportFunc)));
            }
            
            auto validationResult = Memory::PatternScanner::ScanForSignature(validationPattern);
            if (validationResult) {
                m_originalValidationFunc = validationResult.As<void>();
                Logging::LogInfo("TeleportControl", "Found validation function at: " + 
                               std::to_string(reinterpret_cast<uintptr_t>(m_originalValidationFunc)));
            }
            
            // If pattern scanning failed, fall back to symbols
            if (!m_originalTeleportFunc || !m_originalValidationFunc) {
                // Try to find teleport service class through Objective-C runtime
                Class teleportServiceClass = objc_getClass("TeleportService");
                if (teleportServiceClass) {
                    SEL teleportSelector = sel_registerName("teleport:placeId:instanceId:teleportData:success:");
                    Method teleportMethod = class_getInstanceMethod(teleportServiceClass, teleportSelector);
                    if (teleportMethod) {
                        m_originalTeleportFunc = (void*)method_getImplementation(teleportMethod);
                        Logging::LogInfo("TeleportControl", "Found teleport function through Objective-C runtime");
                    }
                    
                    SEL validationSelector = sel_registerName("validateTeleportRequest:requestData:");
                    Method validationMethod = class_getInstanceMethod(teleportServiceClass, validationSelector);
                    if (validationMethod) {
                        m_originalValidationFunc = (void*)method_getImplementation(validationMethod);
                        Logging::LogInfo("TeleportControl", "Found validation function through Objective-C runtime");
                    }
                }
            }
            
            // Return true if we found at least the teleport function
            return m_originalTeleportFunc != nullptr;
            
        } catch (const std::exception& e) {
            Logging::LogError("TeleportControl", "Exception in FindTeleportFunctions: " + std::string(e.what()));
            return false;
        }
    }
    
    bool TeleportControl::BypassTeleportValidation() {
        if (!m_originalValidationFunc) {
            Logging::LogWarning("TeleportControl", "Original validation function not found, cannot bypass");
            return false;
        }
        
        // Hook the validation function
        void* hookAddr = nullptr;
        bool success = Hooks::Implementation::HookFunction(
            m_originalValidationFunc, 
            (void*)ValidationHookFunction, 
            &hookAddr);
        
        if (success && hookAddr) {
            m_teleportValidationHook = m_originalValidationFunc;
            Logging::LogInfo("TeleportControl", "Successfully hooked validation function");
            return true;
        } else {
            Logging::LogError("TeleportControl", "Failed to hook validation function");
            return false;
        }
    }
    
    bool TeleportControl::ModifyTeleportFingerprint(void* request) {
        if (!request) {
            return false;
        }
        
        try {
            // Request structure varies by version, but typically:
            // - First field (offset 0) is a vtable pointer
            // - "Request-Fingerprint" header is usually at offsets 0x20-0x40
            // - "User-Agent" header is usually at offsets 0x48-0x60
            
            // Use MemoryAccess to safely read/write memory
            uint8_t* requestPtr = static_cast<uint8_t*>(request);
            
            // Try to locate fingerprint field (simplified approach)
            const size_t fingerprintFieldOffset = 0x28; // Typical offset, may vary
            
            // Read existing fingerprint pointer
            void* fingerprintPtr = nullptr;
            if (MemoryAccess::ReadMemory(requestPtr + fingerprintFieldOffset, &fingerprintPtr, sizeof(void*))) {
                // If fingerprint exists, modify it to look like server-initiated teleport
                if (fingerprintPtr) {
                    // Generate a server-like fingerprint
                    NSString* serverFingerprint = [NSString stringWithFormat:@"Server-%d-%d", 
                                                 arc4random_uniform(100000), 
                                                 arc4random_uniform(999999)];
                    
                    // Get C string representation
                    const char* serverFingerprintCStr = [serverFingerprint UTF8String];
                    
                    // Create a copy in memory to avoid deallocating the NSString
                    char* fingerprintCopy = strdup(serverFingerprintCStr);
                    
                    // Write the new fingerprint
                    MemoryAccess::WriteMemory(requestPtr + fingerprintFieldOffset, &fingerprintCopy, sizeof(void*));
                    
                    Logging::LogInfo("TeleportControl", "Modified teleport fingerprint to: " + 
                                   std::string(serverFingerprintCStr));
                    return true;
                }
            }
            
            Logging::LogWarning("TeleportControl", "Could not modify teleport fingerprint");
            return false;
            
        } catch (const std::exception& e) {
            Logging::LogError("TeleportControl", "Exception in ModifyTeleportFingerprint: " + std::string(e.what()));
            return false;
        }
    }
}
