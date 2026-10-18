#pragma once

#include <string>
#include <vector>
#include <unordered_map>
#include <mutex>
#include <atomic>
#include <memory>
#include <functional>

// Include necessary headers
#include "../memory/mem.hpp"
#include "../hooks/hooks.hpp"
#include "../logging.hpp"
#include "../globals.hpp"

namespace iOS {
    /**
     * @class PresenceSystem
     * @brief Manages user presence indicators for executor users in-game
     * 
     * This class implements a system that displays a visual tag (a partially open white door
     * with a black background) next to the user's name in game for other executor users to see,
     * creating a network of users who can identify each other.
     */
    class PresenceSystem {
    public:
        // Configuration for presence indicators
        struct PresenceConfig {
            bool enabled;                   // Whether presence system is enabled
            bool showOthers;                // Whether to show other executor users
            bool allowOthersToSeeMe;        // Whether to allow others to see me
            std::string tagId;              // Unique identifier for the tag
            
            PresenceConfig()
                : enabled(true), 
                  showOthers(true), 
                  allowOthersToSeeMe(true),
                  tagId("door_tag") {}
        };
        
        // Player presence information
        struct PlayerInfo {
            std::string userId;             // Roblox user ID
            std::string username;           // Roblox username
            std::string displayName;        // Roblox display name
            std::string tagId;              // Tag identifier
            bool isExecutorUser;            // Whether this player is an executor user
            
            PlayerInfo() : isExecutorUser(false) {}
            
            PlayerInfo(const std::string& id, const std::string& name, const std::string& display)
                : userId(id), username(name), displayName(display), isExecutorUser(false) {}
        };
        
        // Presence update callback type
        using PresenceCallback = std::function<void(const PlayerInfo&)>;
        
        // Singleton instance accessor
        static PresenceSystem& GetInstance();
        
        // Initialize the presence system
        bool Initialize();
        
        // Shutdown and cleanup
        void Shutdown();
        
        // Enable or disable the presence system
        void SetEnabled(bool enabled);
        
        // Check if the system is enabled
        bool IsEnabled() const;
        
        // Get current configuration
        PresenceConfig GetConfig() const;
        
        // Update configuration
        void SetConfig(const PresenceConfig& config);
        
        // Register for presence updates
        void RegisterPresenceCallback(PresenceCallback callback);
        
        // Get all detected executor users
        std::vector<PlayerInfo> GetExecutorUsers();
        
        // Check if a player is an executor user
        bool IsExecutorUser(const std::string& userId);
        
        // Manually refresh presence data
        void RefreshPresence();
        
        // Check if system is initialized
        bool IsInitialized() const { return m_initialized; }
        
    private:
        // Private constructor for singleton
        PresenceSystem();
        
        // No copying allowed
        PresenceSystem(const PresenceSystem&) = delete;
        PresenceSystem& operator=(const PresenceSystem&) = delete;
        
        // Create tag texture/icon
        bool CreateTagAsset();
        
        // Hook player UI functions to add tags
        bool HookPlayerUI();
        
        // Hook network functions to detect other executor users
        bool HookNetworkFunctions();
        
        // Find required player name tag UI functions
        bool FindPlayerNameTagFunctions();
        
        // Generate presence handshake payload
        std::string GenerateHandshakePayload();
        
        // Moved to public access
    public:
        // Process incoming handshake payload
        bool ProcessHandshakePayload(const std::string& payload, const std::string& userId);
        
        // Update player presence in game
        void UpdatePlayerPresence(const PlayerInfo& player);
        
        // Create UI element for tag display
        void* CreateTagUIElement();
        
        // Attach tag to player nametag
        bool AttachTagToPlayer(const std::string& userId, void* tagElement);
        
        // Internal state
        std::atomic<bool> m_initialized;
        std::atomic<bool> m_enabled;
        PresenceConfig m_config;
        
        // Mutex for thread safety
        mutable std::mutex m_mutex;
        
        // Hook addresses - static to allow initialization in static file
        static void* m_nameTagHook;
        static void* m_networkHook;
        static void* m_originalNameTagFunc;
        static void* m_originalNetworkFunc;
        
        // Cache of detected executor users
        std::unordered_map<std::string, PlayerInfo> m_executorUsers;
        
        // Tag UI element cache - static to allow initialization in static file
        static void* m_tagUIElement;
        
        // Tag texture data
        std::vector<uint8_t> m_tagTextureData;
        
        // Presence callbacks
        std::vector<PresenceCallback> m_callbacks;
    };
}
