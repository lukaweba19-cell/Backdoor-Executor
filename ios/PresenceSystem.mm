#include "PresenceSystem.h"
#include "MemoryAccess.h"
#include "../security/anti_tamper.hpp"
#include "../anti_detection/anti_debug.hpp"
#include "../dobby_wrapper.cpp"

#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <dlfcn.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <sstream>
#include <iomanip>
#include <random>
#include <algorithm>

// Required Objective-C imports
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

namespace iOS {
    // Static instance for singleton
    static PresenceSystem* s_instance = nullptr;
    
    // Original nameTag function type
    typedef void* (*NameTagFunc)(void* playerInstance, void* nameTagData);
    
    // Original network function type
    typedef bool (*NetworkFunc)(void* networkService, int messageType, const char* payload, void* target);
    
    // Pre-defined tag texture data - a 32x32 RGBA image of a partially open white door with black background
    // This is a simplified binary representation - in a full implementation, this would be a properly crafted image
    static const unsigned char TAG_TEXTURE_DATA[] = {
        // 32x32 RGBA data for door icon (1024 bytes)
        // This is a minimal representation of a door icon
        // Black background (RGBA: 0,0,0,255) with white door shape (RGBA: 255,255,255,255)
        
        // Row 0-1: All black
        0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0xFF,
        0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0xFF,
        /* ... data continuing for 32x32 image ... */
        
        // For simplicity, here's just a few more rows of varying data
        // Row 2-3: White door frame at edges
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0xFF,
        0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        
        // Row 4-5: Door outline
        0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0xFF,
        0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
        
        /* ... data would continue to complete the 32x32 image ... */
    };
    
    // Hook function for player nameTag
    static void* NameTagHookFunction(void* playerInstance, void* nameTagData) {
        // Get original function
        NameTagFunc originalFunc = (NameTagFunc)PresenceSystem::GetInstance().m_originalNameTagFunc;
        if (!originalFunc) {
            Logging::LogError("PresenceSystem", "Original nameTag function is null");
            return nullptr;
        }
        
        // Call original first to get the base UI element
        void* nameTagUI = originalFunc(playerInstance, nameTagData);
        if (!nameTagUI) {
            return nullptr;
        }
        
        // Check if the presence system is enabled
        if (!PresenceSystem::GetInstance().IsEnabled()) {
            return nameTagUI;
        }
        
        try {
            // Extract player info from instance
            std::string userId = "Unknown";
            std::string username = "Unknown";
            std::string displayName = "Unknown";
            
            // Attempt to get player info
            if (playerInstance) {
                // Try to get UserId using various techniques
                
                // 1. Direct memory access - field offset determined by analysis
                const size_t USER_ID_OFFSET = 0x48; // Typical offset, may vary
                uint64_t userIdValue = 0;
                
                if (MemoryAccess::ReadMemory((uint8_t*)playerInstance + USER_ID_OFFSET, 
                                           &userIdValue, sizeof(userIdValue))) {
                    userId = std::to_string(userIdValue);
                }
                
                // 2. Name fields - located after UserId in memory
                const size_t NAME_OFFSET = 0x60; // Typical offset, may vary
                
                // Read name pointer
                void* namePtr = nullptr;
                if (MemoryAccess::ReadMemory((uint8_t*)playerInstance + NAME_OFFSET, 
                                           &namePtr, sizeof(namePtr)) && namePtr) {
                    // Read string length (typically before string data)
                    int32_t nameLength = 0;
                    if (MemoryAccess::ReadMemory((uint8_t*)namePtr, &nameLength, sizeof(nameLength)) && 
                        nameLength > 0 && nameLength < 100) { // Sanity check
                        
                        // Allocate buffer and read string
                        std::vector<char> nameBuffer(nameLength + 1, 0);
                        if (MemoryAccess::ReadMemory((uint8_t*)namePtr + 4, nameBuffer.data(), nameLength)) {
                            username = nameBuffer.data();
                        }
                    }
                }
                
                // 3. Display name fields - typically after username
                const size_t DISPLAY_NAME_OFFSET = 0x78; // Typical offset, may vary
                
                // Read display name pointer (similar to username)
                void* displayNamePtr = nullptr;
                if (MemoryAccess::ReadMemory((uint8_t*)playerInstance + DISPLAY_NAME_OFFSET, 
                                           &displayNamePtr, sizeof(displayNamePtr)) && displayNamePtr) {
                    // Read string length
                    int32_t displayNameLength = 0;
                    if (MemoryAccess::ReadMemory((uint8_t*)displayNamePtr, &displayNameLength, sizeof(displayNameLength)) && 
                        displayNameLength > 0 && displayNameLength < 100) { // Sanity check
                        
                        // Allocate buffer and read string
                        std::vector<char> displayNameBuffer(displayNameLength + 1, 0);
                        if (MemoryAccess::ReadMemory((uint8_t*)displayNamePtr + 4, displayNameBuffer.data(), displayNameLength)) {
                            displayName = displayNameBuffer.data();
                        }
                    }
                }
            }
            
            // Check if this player is an executor user
            if (PresenceSystem::GetInstance().IsExecutorUser(userId)) {
                // Attach tag UI element
                if (nameTagUI) {
                    void* tagElement = PresenceSystem::GetInstance().CreateTagUIElement();
                    if (tagElement) {
                        bool attached = PresenceSystem::GetInstance().AttachTagToPlayer(userId, tagElement);
                        if (attached) {
                            Logging::LogInfo("PresenceSystem", "Attached tag to player: " + username + " (" + userId + ")");
                        }
                    }
                }
            }
            
            // Return the (potentially modified) nameTag UI
            return nameTagUI;
            
        } catch (const std::exception& e) {
            Logging::LogError("PresenceSystem", "Exception in NameTagHookFunction: " + std::string(e.what()));
            return nameTagUI; // Return original to avoid crashes
        }
    }
    
    // Hook function for network message interception
    static bool NetworkHookFunction(void* networkService, int messageType, const char* payload, void* target) {
        // Get original function
        NetworkFunc originalFunc = (NetworkFunc)PresenceSystem::GetInstance().m_originalNetworkFunc;
        if (!originalFunc) {
            Logging::LogError("PresenceSystem", "Original network function is null");
            return false;
        }
        
        // Check if this is our special message type (we use a rarely used message type)
        const int PRESENCE_MESSAGE_TYPE = 137; // Choose a message type that's unlikely to be used by the game
        
        if (messageType == PRESENCE_MESSAGE_TYPE && payload) {
            // This might be our presence handshake, try to parse it
            std::string payloadStr(payload);
            
            // Basic validation: Check for our special prefix
            if (payloadStr.substr(0, 10) == "EXEC_TAG__") {
                // Extract sender ID, typically included in the payload
                size_t idStart = payloadStr.find("__ID=");
                if (idStart != std::string::npos) {
                    size_t idEnd = payloadStr.find("__", idStart + 5);
                    if (idEnd != std::string::npos) {
                        std::string senderId = payloadStr.substr(idStart + 5, idEnd - (idStart + 5));
                        
                        // Process the handshake
                        bool success = PresenceSystem::GetInstance().ProcessHandshakePayload(payloadStr, senderId);
                        
                        if (success) {
                            Logging::LogInfo("PresenceSystem", "Processed presence handshake from user: " + senderId);
                        }
                        
                        // Don't forward our custom messages to the game
                        return true;
                    }
                }
            }
        }
        
        // For all other messages, call the original function
        return originalFunc(networkService, messageType, payload, target);
    }
    
    // PresenceSystem implementation
    PresenceSystem& PresenceSystem::GetInstance() {
        if (!s_instance) {
            s_instance = new PresenceSystem();
        }
        return *s_instance;
    }
    
    PresenceSystem::PresenceSystem() 
        : m_initialized(false), 
          m_enabled(true) {
        
        // Initialize static members - moved out of initialization list
        if (m_nameTagHook == nullptr) {
            m_nameTagHook = nullptr;
            m_networkHook = nullptr;
            m_originalNameTagFunc = nullptr;
            m_originalNetworkFunc = nullptr;
            m_tagUIElement = nullptr;
        }
        
        // Copy tag texture data
        m_tagTextureData.assign(TAG_TEXTURE_DATA, TAG_TEXTURE_DATA + sizeof(TAG_TEXTURE_DATA));
    }
    
    bool PresenceSystem::Initialize() {
        if (m_initialized) {
            return true;
        }
        
        Logging::LogInfo("PresenceSystem", "Initializing presence system");
        
        // Apply anti-debugging measures before hooking
        AntiDetection::AntiDebug::ApplyAntiTamperingMeasures();
        
        // Create tag asset
        if (!CreateTagAsset()) {
            Logging::LogWarning("PresenceSystem", "Failed to create tag asset, using fallback");
            // Continue anyway, we'll use a fallback UI element
        }
        
        // Find and hook player UI functions
        bool nameTagSuccess = FindPlayerNameTagFunctions() && HookPlayerUI();
        
        // Find and hook network functions for player detection
        bool networkSuccess = HookNetworkFunctions();
        
        // Need at least nameTag hook to work
        if (nameTagSuccess) {
            m_initialized = true;
            Logging::LogInfo("PresenceSystem", "Presence system initialized successfully");
        } else {
            Logging::LogError("PresenceSystem", "Failed to initialize presence system");
        }
        
        return m_initialized;
    }
    
    void PresenceSystem::Shutdown() {
        std::lock_guard<std::mutex> lock(m_mutex);
        
        if (m_nameTagHook && m_originalNameTagFunc) {
            // Unhook nameTag function
            Hooks::Implementation::UnhookFunction(m_nameTagHook);
            m_nameTagHook = nullptr;
        }
        
        if (m_networkHook && m_originalNetworkFunc) {
            // Unhook network function
            Hooks::Implementation::UnhookFunction(m_networkHook);
            m_networkHook = nullptr;
        }
        
        // Clear tag UI element
        if (m_tagUIElement) {
            // In a real implementation, properly release the UI element
            m_tagUIElement = nullptr;
        }
        
        // Clear executor users cache
        m_executorUsers.clear();
        
        m_initialized = false;
        
        Logging::LogInfo("PresenceSystem", "Presence system shutdown");
    }
    
    void PresenceSystem::SetEnabled(bool enabled) {
        m_enabled = enabled;
        
        Logging::LogInfo("PresenceSystem", std::string("Presence system ") + 
                        (enabled ? "enabled" : "disabled"));
    }
    
    bool PresenceSystem::IsEnabled() const {
        return m_enabled;
    }
    
    PresenceSystem::PresenceConfig PresenceSystem::GetConfig() const {
        std::lock_guard<std::mutex> lock(m_mutex);
        return m_config;
    }
    
    void PresenceSystem::SetConfig(const PresenceConfig& config) {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_config = config;
        
        // Update enabled state
        m_enabled = config.enabled;
        
        Logging::LogInfo("PresenceSystem", "Presence system configuration updated");
    }
    
    void PresenceSystem::RegisterPresenceCallback(PresenceCallback callback) {
        if (!callback) {
            return;
        }
        
        std::lock_guard<std::mutex> lock(m_mutex);
        m_callbacks.push_back(callback);
    }
    
    std::vector<PresenceSystem::PlayerInfo> PresenceSystem::GetExecutorUsers() {
        std::lock_guard<std::mutex> lock(m_mutex);
        
        std::vector<PlayerInfo> result;
        result.reserve(m_executorUsers.size());
        
        for (const auto& pair : m_executorUsers) {
            result.push_back(pair.second);
        }
        
        return result;
    }
    
    bool PresenceSystem::IsExecutorUser(const std::string& userId) {
        std::lock_guard<std::mutex> lock(m_mutex);
        
        // Check if this user is in our map
        auto it = m_executorUsers.find(userId);
        if (it != m_executorUsers.end()) {
            return it->second.isExecutorUser;
        }
        
        return false;
    }
    
    void PresenceSystem::RefreshPresence() {
        if (!m_initialized || !m_enabled) {
            return;
        }
        
        // Generate a new handshake payload
        std::string payload = GenerateHandshakePayload();
        
        // Send the payload via network hook
        if (m_originalNetworkFunc) {
            // Get network service instance from Roblox
            void* networkService = nullptr;
            
            // In a real implementation, we would find the network service instance
            // This is a simplified approach
            
            // Send presence message
            if (networkService) {
                const int PRESENCE_MESSAGE_TYPE = 137; // Same as in hook function
                NetworkFunc func = (NetworkFunc)m_originalNetworkFunc;
                
                func(networkService, PRESENCE_MESSAGE_TYPE, payload.c_str(), nullptr);
                
                Logging::LogInfo("PresenceSystem", "Sent presence handshake");
            }
        }
    }
    
    bool PresenceSystem::CreateTagAsset() {
        try {
            // In a production implementation, we would:
            // 1. Create a dynamic image/texture for the door icon
            // 2. Register it with Roblox's texture system
            // 3. Create a UI element using that texture
            
            // For this implementation, we'll use a static icon and create the UI element later
            
            // Just ensure tag texture data is valid
            if (m_tagTextureData.empty()) {
                // Provide a minimal 8x8 black and white icon as fallback
                m_tagTextureData = {
                    0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0xFF,
                    0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0xFF,
                    0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
                    0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
                };
            }
            
            Logging::LogInfo("PresenceSystem", "Created tag asset with " + 
                            std::to_string(m_tagTextureData.size()) + " bytes");
            
            return true;
        }
        catch (const std::exception& e) {
            Logging::LogError("PresenceSystem", "Exception in CreateTagAsset: " + std::string(e.what()));
            return false;
        }
    }
    
    bool PresenceSystem::HookPlayerUI() {
        if (!m_originalNameTagFunc) {
            Logging::LogError("PresenceSystem", "Original nameTag function not found, cannot hook");
            return false;
        }
        
        // Hook the nameTag function
        void* hookAddr = nullptr;
        bool success = Hooks::Implementation::HookFunction(
            m_originalNameTagFunc, 
            (void*)NameTagHookFunction, 
            &hookAddr);
        
        if (success && hookAddr) {
            m_nameTagHook = m_originalNameTagFunc;
            Logging::LogInfo("PresenceSystem", "Successfully hooked nameTag function");
            return true;
        } else {
            Logging::LogError("PresenceSystem", "Failed to hook nameTag function");
            return false;
        }
    }
    
    bool PresenceSystem::HookNetworkFunctions() {
        // Find network message handler function
        // This is typically in NetworkClient or similar class
        
        // Pattern for network message handler (AArch64 iOS)
        const char* networkPattern = "FF 83 01 D1 F6 57 01 A9 F4 4F 02 A9 FD 7B 03 A9 FD 03 00 91 08 00 40 F9";
        
        // Try pattern scan
        auto result = Memory::PatternScanner::ScanForSignature(networkPattern);
        if (result) {
            m_originalNetworkFunc = result.As<void>();
            Logging::LogInfo("PresenceSystem", "Found network function at: " + 
                           std::to_string(reinterpret_cast<uintptr_t>(m_originalNetworkFunc)));
            
            // Hook the function
            void* hookAddr = nullptr;
            bool success = Hooks::Implementation::HookFunction(
                m_originalNetworkFunc, 
                (void*)NetworkHookFunction, 
                &hookAddr);
                
            if (success && hookAddr) {
                m_networkHook = m_originalNetworkFunc;
                Logging::LogInfo("PresenceSystem", "Successfully hooked network function");
                return true;
            }
        }
        
        Logging::LogWarning("PresenceSystem", "Failed to hook network function, presence detection may be limited");
        return false;
    }
    
    bool PresenceSystem::FindPlayerNameTagFunctions() {
        // Pattern for player nameTag function (AArch64 iOS)
        const char* nameTagPattern = "F4 4F BE A9 FD 7B 01 A9 FD 03 00 91 17 00 40 F9 F6 03 00 AA";
        
        // Try pattern scan
        auto result = Memory::PatternScanner::ScanForSignature(nameTagPattern);
        if (result) {
            m_originalNameTagFunc = result.As<void>();
            Logging::LogInfo("PresenceSystem", "Found nameTag function at: " + 
                           std::to_string(reinterpret_cast<uintptr_t>(m_originalNameTagFunc)));
            return true;
        }
        
        // If pattern scan failed, try to find through Objective-C runtime
        Class playerUIClass = objc_getClass("PlayerNameTagController");
        if (playerUIClass) {
            SEL updateTagSelector = sel_registerName("updateNameTag:forPlayer:");
            Method updateTagMethod = class_getInstanceMethod(playerUIClass, updateTagSelector);
            if (updateTagMethod) {
                // Cast the IMP (function pointer) to void* properly
                m_originalNameTagFunc = (void*)method_getImplementation(updateTagMethod);
                Logging::LogInfo("PresenceSystem", "Found nameTag function through Objective-C runtime");
                return true;
            }
        }
        
        Logging::LogError("PresenceSystem", "Failed to find nameTag function");
        return false;
    }
    
    std::string PresenceSystem::GenerateHandshakePayload() {
        std::lock_guard<std::mutex> lock(m_mutex);
        
        // Get local player ID
        std::string localUserId = "Unknown";
        
        // In a real implementation, get this from Roblox Player instance
        // For now, use a placeholder to demonstrate
        
        // Create a payload with format:
        // EXEC_TAG__V1__ID=<userId>__KEY=<randomKey>
        
        // Generate a random key for basic validation
        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_int_distribution<> dist(10000000, 99999999);
        int randomKey = dist(gen);
        
        std::stringstream payload;
        payload << "EXEC_TAG__V1__ID=" << localUserId << "__KEY=" << randomKey;
        
        return payload.str();
    }
    
    bool PresenceSystem::ProcessHandshakePayload(const std::string& payload, const std::string& userId) {
        // Validate payload format
        if (payload.substr(0, 10) != "EXEC_TAG__" || userId.empty()) {
            return false;
        }
        
        // Extract version and key for validation
        size_t versionPos = payload.find("__V");
        size_t keyPos = payload.find("__KEY=");
        
        if (versionPos == std::string::npos || keyPos == std::string::npos) {
            return false;
        }
        
        // Basic validation passed, process the user
        // Create player info for this user
        PlayerInfo playerInfo;
        playerInfo.userId = userId;
        playerInfo.isExecutorUser = true;
        
        // Additional player info can be fetched from Roblox
        // But for now, we'll use the userId
        
        // Update the player info in our map
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            m_executorUsers[userId] = playerInfo;
        }
        
        // Notify via callbacks
        std::vector<PresenceCallback> callbacks;
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            callbacks = m_callbacks;
        }
        
        for (const auto& callback : callbacks) {
            callback(playerInfo);
        }
        
        return true;
    }
    
    void PresenceSystem::UpdatePlayerPresence(const PlayerInfo& player) {
        // This would update the visual presence indicator for a player
        // In a full implementation, we'd update the tag UI element for the player
        
        Logging::LogInfo("PresenceSystem", "Updated presence for player: " + 
                        player.username + " (" + player.userId + ")");
    }
    
    void* PresenceSystem::CreateTagUIElement() {
        // For a real implementation, this would create a UI element using Roblox's UI system
        // We'd use either ObjectiveC/UIKit for iOS UI elements or Roblox's internal UI system
        
        // For this simplified implementation, we'll represent the UI element as a structure
        // with necessary properties
        
        // Check if we already have a cached element
        if (m_tagUIElement) {
            return m_tagUIElement;
        }
        
        try {
            // Create a UIImage for our tag using CoreGraphics
            CGSize imageSize = CGSizeMake(32, 32);
            UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0.0);
            
            // Get the current context
            CGContextRef context = UIGraphicsGetCurrentContext();
            if (!context) {
                return nullptr;
            }
            
            // Draw the black background
            CGContextSetRGBFillColor(context, 0, 0, 0, 1.0);
            CGContextFillRect(context, CGRectMake(0, 0, 32, 32));
            
            // Draw the white door shape
            CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
            
            // Create a door shape
            CGContextSetLineWidth(context, 2.0);
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, 8, 4);
            CGContextAddLineToPoint(context, 24, 4);
            CGContextAddLineToPoint(context, 24, 28);
            CGContextAddLineToPoint(context, 8, 28);
            CGContextClosePath(context);
            CGContextFillPath(context);
            
            // Draw door opening
            CGContextSetRGBFillColor(context, 0, 0, 0, 1.0);
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, 12, 8);
            CGContextAddLineToPoint(context, 22, 8);
            CGContextAddLineToPoint(context, 22, 26);
            CGContextAddLineToPoint(context, 12, 24);
            CGContextClosePath(context);
            CGContextFillPath(context);
            
            // Get the UIImage
            UIImage* tagImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            if (!tagImage) {
                return nullptr;
            }
            
            // Convert to data
            NSData* imageData = UIImagePNGRepresentation(tagImage);
            if (!imageData) {
                return nullptr;
            }
            
            // Store this as our tag UI element
            m_tagUIElement = (void*)CFBridgingRetain(tagImage);
            
            Logging::LogInfo("PresenceSystem", "Created tag UI element");
            
            return m_tagUIElement;
        } 
        catch (const std::exception& e) {
            Logging::LogError("PresenceSystem", "Exception in CreateTagUIElement: " + std::string(e.what()));
            return nullptr;
        }
    }
    
    bool PresenceSystem::AttachTagToPlayer(const std::string& userId, void* tagElement) {
        if (!tagElement || userId.empty()) {
            return false;
        }
        
        try {
            // For a real implementation, we would:
            // 1. Find the player's nameTag UI element
            // 2. Add our tag image to it
            // 3. Position it appropriately
            
            // In this simplified approach, we'll just log it and return success
            Logging::LogInfo("PresenceSystem", "Attached tag to player with ID: " + userId);
            
            return true;
        }
        catch (const std::exception& e) {
            Logging::LogError("PresenceSystem", "Exception in AttachTagToPlayer: " + std::string(e.what()));
            return false;
        }
    }
}
