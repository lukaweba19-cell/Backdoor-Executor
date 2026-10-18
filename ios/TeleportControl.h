#pragma once

#include <string>
#include <functional>
#include <atomic>
#include <mutex>
#include <vector>
#include <unordered_map>
#include <memory>

// Include necessary headers
#include "../hooks/hooks.hpp"
#include "../memory/mem.hpp"
#include "../logging.hpp"
#include "../globals.hpp"

// No need to redefine BypassIntegrityChecks since it's already in globals.hpp

namespace iOS {
    /**
     * @class TeleportControl
     * @brief Controls Roblox teleport functionality allowing users to block unwanted teleports
     * 
     * This class provides functionality to:
     * 1. Block forced teleports from games
     * 2. Bypass teleport validation for certain destinations
     * 3. Allow manual control over when teleports are accepted
     */
    class TeleportControl {
    public:
        // Teleport types for different control levels
        enum class TeleportType {
            ServerTeleport,        // Teleport to another server of same game
            GameTeleport,          // Teleport to a different game
            PrivateServerTeleport, // Teleport to a private server
            ReservedServerTeleport,// Teleport to a reserved server
            FriendTeleport,        // Teleport to a friend
            ExtensionTeleport      // Teleport to a game extension
        };
        
        // Teleport control mode
        enum class ControlMode {
            AllowAll,              // Allow all teleports (default Roblox behavior)
            BlockAll,              // Block all teleports
            PromptUser,            // Ask user before teleporting
            CustomRules            // Use custom rules based on teleport type
        };
        
        // Teleport event callback type
        using TeleportCallback = std::function<bool(TeleportType, const std::string&, const std::string&)>;
        
        // Singleton instance accessor
        static TeleportControl& GetInstance();
        
        // Initialize teleport control system
        bool Initialize();
        
        // Shutdown and cleanup hooks
        void Shutdown();
        
        // Set teleport control mode
        void SetControlMode(ControlMode mode);
        
        // Get current control mode
        ControlMode GetControlMode() const;
        
        // Set custom rule for specific teleport type
        void SetCustomRule(TeleportType type, bool allow);
        
        // Register teleport event callback
        void RegisterCallback(TeleportCallback callback);
        
        // Process a teleport request - returns true if teleport should proceed
        bool ProcessTeleportRequest(TeleportType type, const std::string& destination, const std::string& placeId);
        
        // Get last teleport attempt info
        std::pair<std::string, std::string> GetLastTeleportInfo() const;
        
        // Check if system is properly initialized
        bool IsInitialized() const { return m_initialized; }
        
    private:
        // Private constructor for singleton
        TeleportControl();
        
        // No copying allowed
        TeleportControl(const TeleportControl&) = delete;
        TeleportControl& operator=(const TeleportControl&) = delete;
        
        // Hook teleport function in Roblox
        bool HookTeleportService();
        
        // Find teleport functions in memory
        bool FindTeleportFunctions();
        
        // Bypass teleport validation restrictions
        bool BypassTeleportValidation();
        // Internal state
        std::atomic<bool> m_initialized;
        ControlMode m_controlMode;
        
        // Mutex for thread safety
        mutable std::mutex m_mutex;
        
        // Custom rules for teleport types
        std::unordered_map<TeleportType, bool> m_customRules;
        
        // Last teleport info
        std::string m_lastDestination;
        std::string m_lastPlaceId;
        
        // Moved to public for static function access
    public:
        // Teleport hooks - static to allow initialization in static file
        static void* m_teleportHook;
        static void* m_teleportValidationHook;
        static void* m_originalTeleportFunc;
        static void* m_originalValidationFunc;
        
        // Modify teleport request fingerprints
        bool ModifyTeleportFingerprint(void* request);
        
        // Event callbacks
        std::vector<TeleportCallback> m_callbacks;
    };
}
