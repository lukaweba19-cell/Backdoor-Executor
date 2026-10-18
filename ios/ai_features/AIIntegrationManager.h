
#include "objc_isolation.h"
#pragma once

#include <string>
#include <vector>
#include <functional>
#include <memory>
#include <unordered_map>
#include "ScriptAssistant.h"
#include "SignatureAdaptation.h"
#include "HybridAISystem.h"
#include "AIConfig.h"
#include "OnlineService.h"
#include "AISystemInitializer.h"

namespace iOS {
namespace AIFeatures {

/**
 * @class AIIntegrationManager
 * @brief Manages the integration of all AI components
 * 
 * This class serves as the main entry point for using AI features in the executor.
 * It coordinates the ScriptAssistant, SignatureAdaptation, and networking components
 * to provide a unified interface that is online-only (offline mode removed).
 */
class AIIntegrationManager {
public:
    // AI capability flags
    enum AICapability {
        SCRIPT_GENERATION = 0x01,    // Generate scripts
        SCRIPT_DEBUGGING = 0x02,     // Debug scripts
        SCRIPT_ANALYSIS = 0x04,      // Analyze scripts
        GAME_ANALYSIS = 0x08,        // Analyze games
        SIGNATURE_ADAPTATION = 0x10, // Anti-cheat adaptation
        ONLINE_ENHANCED = 0x20,      // Enhanced online features
        FULL_CAPABILITIES = 0xFF     // All capabilities
    };
    
    // Status update structure
    struct StatusUpdate {
        std::string m_status;         // Status message
        float m_progress;             // Progress value (0.0-1.0)
        bool m_isError;               // Whether status is an error
        
        StatusUpdate() : m_progress(0.0f), m_isError(false) {}
        
        StatusUpdate(const std::string& status, float progress = 0.0f, bool isError = false)
            : m_status(status), m_progress(progress), m_isError(isError) {}
    };
    
    // Callback types
    using StatusCallback = std::function<void(const StatusUpdate&)>;
    using ScriptGenerationCallback = std::function<void(const std::string&)>;
    using DebugResultCallback = std::function<void(const std::string&)>;
    using QueryResponseCallback = std::function<void(const std::string&)>;
    
private:
    // Singleton instance
    static AIIntegrationManager* s_instance;
    
    // Member variables
    std::shared_ptr<::iOS::AIFeatures::ScriptAssistant> m_scriptAssistant;       // Script assistant
    std::shared_ptr<::iOS::AIFeatures::SignatureAdaptation> m_signatureAdaptation; // Signature adaptation
    std::shared_ptr<::iOS::AIFeatures::HybridAISystem> m_hybridAI;               // Hybrid AI system
    std::shared_ptr<::iOS::AIFeatures::OnlineService> m_onlineService;           // Online service
    std::shared_ptr<::iOS::AIFeatures::AISystemInitializer> m_aiSystemInitializer; // AI system initializer
    ::iOS::AIFeatures::AIConfig& m_config;                                       // AI configuration
    StatusCallback m_statusCallback;                          // Status callback
    uint32_t m_availableCapabilities;                         // Available capabilities
    bool m_initialized;                                       // Initialization flag
    bool m_initializing;                                      // Initialization in progress flag
    bool m_online;                                            // Online status
    
    // Private constructor for singleton
    AIIntegrationManager();
    
    // Initialize components
    void InitializeComponents();
    
    // Update online status
    void UpdateOnlineStatus(bool isOnline);
    
    // Report status update
    void ReportStatus(const StatusUpdate& status);
    
    // Get optimal online mode
    ::iOS::AIFeatures::HybridAISystem::OnlineMode GetOptimalOnlineMode() const;
    
public:
    /**
     * @brief Get shared instance
     * @return Shared instance
     */
    static AIIntegrationManager& GetSharedInstance();
    
    /**
     * @brief Destructor
     */
    ~AIIntegrationManager();
    
    /**
     * @brief Initialize the manager
     * @param apiKey Optional API key for online features
     * @param statusCallback Optional callback for initialization status
     * @return True if initialization started successfully
     */
    bool Initialize(const std::string& apiKey = "", StatusCallback statusCallback = nullptr);
    
    /**
     * @brief Check if manager is initialized
     * @return True if initialized
     */
    bool IsInitialized() const;
    
    /**
     * @brief Check if online mode is available
     * @return True if online mode is available
     */
    bool IsOnlineAvailable() const;
    
    /**
     * @brief Get available AI capabilities
     * @return Bit flags of available capabilities
     */
    uint32_t GetAvailableCapabilities() const;
    
    /**
     * @brief Check if a specific capability is available
     * @param capability Capability to check
     * @return True if capability is available
     */
    bool HasCapability(AICapability capability) const;
    
    /**
     * @brief Generate a script
     * @param description Script description
     * @param context Additional context (e.g., game type)
     * @param callback Function to call with the generated script
     * @param useOnline Whether to use online processing if available
     */
    void GenerateScript(const std::string& description, 
                       const std::string& context,
                       ScriptGenerationCallback callback,
                       bool useOnline = true);
    
    /**
     * @brief Debug a script
     * @param script Script to debug
     * @param callback Function to call with debug results
     * @param useOnline Whether to use online processing if available
     */
    void DebugScript(const std::string& script,
                    DebugResultCallback callback,
                    bool useOnline = true);
    
    /**
     * @brief Process a general query
     * @param query User query
     * @param callback Function to call with the response
     * @param useOnline Whether to use online processing if available
     */
    void ProcessQuery(const std::string& query,
                     QueryResponseCallback callback,
                     bool useOnline = true);
    
    /**
     * @brief Report detection event to signature adaptation
     * @param detectionType Type of detection
     * @param signature Binary signature data
     */
    void ReportDetection(const std::string& detectionType,
                        const std::vector<uint8_t>& signature);
    
    /**
     * @brief Get signature adaptation system
     * @return Signature adaptation system
     */
    std::shared_ptr<::iOS::AIFeatures::SignatureAdaptation> GetSignatureAdaptation() const;
    
    /**
     * @brief Get script assistant
     * @return Script assistant
     */
    std::shared_ptr<::iOS::AIFeatures::ScriptAssistant> GetScriptAssistant() const;
    
    /**
     * @brief Get hybrid AI system
     * @return Hybrid AI system
     */
    std::shared_ptr<::iOS::AIFeatures::HybridAISystem> GetHybridAI() const;
    
    /**
     * @brief Get online service
     * @return Online service
     */
    std::shared_ptr<::iOS::AIFeatures::OnlineService> GetOnlineService() const;
    
    /**
     * @brief Set API key
     * @param apiKey API key
     */
    void SetAPIKey(const std::string& apiKey);
    
    /**
     * @brief Set online mode
     * @param mode Online mode
     */
    void SetOnlineMode(::iOS::AIFeatures::HybridAISystem::OnlineMode mode);
    
    /**
     * @brief Get online mode
     * @return Current online mode
     */
    ::iOS::AIFeatures::HybridAISystem::OnlineMode GetOnlineMode() const;
    
    /**
     * @brief Set model quality
     * @param quality Model quality
     */
    void SetModelQuality(::iOS::AIFeatures::AIConfig::ModelQuality quality);
    
    /**
     * @brief Get model quality
     * @return Current model quality
     */
    ::iOS::AIFeatures::AIConfig::ModelQuality GetModelQuality() const;
    
    /**
     * @brief Handle memory warning
     */
    void HandleMemoryWarning();
    
    /**
     * @brief Handle app entering foreground
     */
    void HandleAppForeground();
    
    /**
     * @brief Handle app entering background
     */
    void HandleAppBackground();
    
    /**
     * @brief Handle network status change
     * @param isOnline Whether network is online
     */
    void HandleNetworkStatusChange(bool isOnline);
    
    /**
     * @brief Get memory usage
     * @return Memory usage in bytes
     */
    uint64_t GetMemoryUsage() const;
    
    /**
     * @brief Save configuration changes
     * @return True if save was successful
     */
    bool SaveConfig();
};

} // namespace AIFeatures
} // namespace iOS
