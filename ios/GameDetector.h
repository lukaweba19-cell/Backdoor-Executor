// Game detection and monitoring
#pragma once

#include "objc_isolation.h"
#include "PatternScanner.h"
#include "MemoryAccess.h"
#include "mach_compat.h"
#include <string>
#include <atomic>
#include <thread>
#include <functional>

namespace iOS {
    // Game state enum
    enum class GameState {
        Unknown,
        NotRunning,
        Connecting,
        InGame,
        InMenu
    };
    
    // Game detection offsets
    struct RobloxOffsets {
        uintptr_t baseAddress;
        uintptr_t scriptContext;
        uintptr_t luaState;
        uintptr_t dataModel;
    };
    
    // Game detector class
    class GameDetector {
    private:
        // State tracking
        std::atomic<GameState> m_currentState;
        std::atomic<bool> m_running;
        std::atomic<uint64_t> m_lastChecked;
        std::atomic<uint64_t> m_lastGameJoinTime;
        std::string m_currentGameName;
        std::string m_currentPlaceId;
        RobloxOffsets m_offsets;
        
        // Detection methods
        void UpdateGameState();
        bool UpdateRobloxOffsets();
        bool InitializeMemoryAccess();
        void NotifyStateChange(GameState newState);
        bool CheckRobloxRunning();
        void DetectCurrentGame();
        void WorkerThread();
        std::string GetGameNameFromMemory();
        std::string GetPlaceIdFromMemory();
        std::string ReadRobloxString(mach_vm_address_t stringPtr);
        
        // Worker thread
        std::thread m_workerThread;
        
    public:
        // Constructor and destructor
        GameDetector();
        ~GameDetector();
        
        // Non-copyable
        GameDetector(const GameDetector&) = delete;
        GameDetector& operator=(const GameDetector&) = delete;
        
        // Start/stop detection
        bool Start();
        void Stop();
        
        // Get current state
        GameState GetCurrentState() const;
        bool IsInGame() const;
        
        // Get game info
        std::string GetCurrentGameName() const;
        std::string GetCurrentPlaceId() const;
        uint64_t GetGameJoinTime() const;
        
        // Callback for state changes
        void SetStateChangeCallback(std::function<void(GameState)> callback);
        
        // Get Roblox offsets
        RobloxOffsets GetOffsets() const;
    
    // Aliases for game information
    std::string GetGameName() const { return GetCurrentGameName(); }
    std::string GetPlaceId() const { return GetCurrentPlaceId(); }
    };
}
