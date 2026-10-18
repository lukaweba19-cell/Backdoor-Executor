
#include "ios_compat.h"
#include "AIIntegrationManager.h"
#include <iostream>
#include <thread>

namespace iOS {
namespace AIFeatures {

// Initialize static instance
AIIntegrationManager* AIIntegrationManager::s_instance = nullptr;

// Constructor
AIIntegrationManager::AIIntegrationManager()
    : m_config(AIConfig::GetSharedInstance()),
      m_availableCapabilities(0),
      m_initialized(false),
      m_initializing(false),
      m_online(false) {
}

// Destructor
AIIntegrationManager::~AIIntegrationManager() {
    // Make sure config is saved
    m_config.Save();
}

// Get shared instance
AIIntegrationManager& AIIntegrationManager::GetSharedInstance() {
    if (!s_instance) {
        s_instance = new AIIntegrationManager();
    }
    return *s_instance;
}

// Initialize the manager
bool AIIntegrationManager::Initialize(const std::string& apiKey, StatusCallback statusCallback) {
    // Check if already initialized or initializing
    if (m_initialized || m_initializing) {
        return true;
    }
    
    // Set initializing flag
    m_initializing = true;
    
    // Store callback
    m_statusCallback = statusCallback;
    
    // Report initialization started
    ReportStatus(StatusUpdate("Initializing AI components...", 0.0f));
    
    // Set API key if provided
    if (!apiKey.empty()) {
        m_config.SetAPIKey(apiKey);
        m_config.Save();
    }
    
    // Initialize config if not already initialized
    if (!m_config.IsInitialized()) {
        m_config.Initialize();
    }
    
    // Initialize components in background
    std::thread([this]() {
        InitializeComponents();
    }).detach();
    
    return true;
}

// Initialize components
void AIIntegrationManager::InitializeComponents() {
    try {
        // Create and initialize online service with configured API values
        ReportStatus(StatusUpdate("Initializing network services...", 0.1f));
        
        m_onlineService = std::make_shared<OnlineService>();
        bool onlineInitialized = m_onlineService->Initialize(
            m_config.GetAPIEndpoint(),
            m_config.GetAPIKey()
        );
        
        if (onlineInitialized) {
            // Set up network callback
            m_onlineService->SetNetworkStatusCallback([this](OnlineService::NetworkStatus status) {
                bool isOnline = (status == OnlineService::NetworkStatus::ReachableViaWiFi || 
                               status == OnlineService::NetworkStatus::ReachableViaCellular);
                UpdateOnlineStatus(isOnline);
            });
            
            // Set encryption based on config
            m_onlineService->SetEncryption(m_config.GetEncryptCommunication());
            
            // Get initial online status
            m_online = m_onlineService->IsNetworkReachable();
        } else {
            m_online = false;
        }
        
        // Online-only Hybrid AI (no local models / training)
        ReportStatus(StatusUpdate("Initializing online AI system...", 0.2f));
        
        m_hybridAI = std::make_shared<HybridAISystem>();
        bool hybridInitialized = m_hybridAI->Initialize(
            "",
            m_config.GetAPIEndpoint(),
            m_config.GetAPIKey(),
            HybridAISystem::OnlineMode::OnlineOnly
        );
        
        if (hybridInitialized) {
            m_hybridAI->SetOnlineMode(GetOptimalOnlineMode());
            std::string model = m_config.GetOption("model", "openrouter/free");
            m_hybridAI->SetModel(model);
        }
        
        ReportStatus(StatusUpdate("Initializing AI config shell...", 0.65f));
        m_aiSystemInitializer = std::shared_ptr<AISystemInitializer>(AISystemInitializer::GetInstance(),
            [](AISystemInitializer*) {});
        m_aiSystemInitializer->Initialize();
        
        // Create and initialize script assistant
        ReportStatus(StatusUpdate("Initializing script assistant...", 0.7f));
        
        m_scriptAssistant = std::make_shared<ScriptAssistant>();
        bool assistantInitialized = m_scriptAssistant->Initialize();
        
        // Create and initialize signature adaptation
        ReportStatus(StatusUpdate("Initializing security adaptations...", 0.8f));
        
        m_signatureAdaptation = std::make_shared<SignatureAdaptation>();
        if (m_hybridAI) m_signatureAdaptation->SetHybridAI(m_hybridAI);
        bool adaptationInitialized = m_signatureAdaptation->Initialize();
        
        // Determine available capabilities
        m_availableCapabilities = 0;
        
        // Basic capabilities require network (offline models removed)
        if (hybridInitialized) {
            m_availableCapabilities |= SCRIPT_GENERATION;
            m_availableCapabilities |= SCRIPT_DEBUGGING;
        }
        
        if (assistantInitialized) {
            m_availableCapabilities |= SCRIPT_ANALYSIS;
        }
        
        if (adaptationInitialized) {
            m_availableCapabilities |= SIGNATURE_ADAPTATION;
        }
        
        // Enhanced capabilities available when online
        if (onlineInitialized && m_online) {
            m_availableCapabilities |= GAME_ANALYSIS;
            m_availableCapabilities |= ONLINE_ENHANCED;
        }
        
        // Set initialization completed
        m_initialized = true;
        m_initializing = false;
        
        // Report initialization completed
        ReportStatus(StatusUpdate("AI system initialization complete.", 1.0f));
    } catch (const std::exception& e) {
        // Report initialization error
        std::string errorMsg = "AI initialization failed: ";
        errorMsg += e.what();
        ReportStatus(StatusUpdate(errorMsg, 1.0f, true));
        
        // Set not initializing
        m_initializing = false;
    }
}

// Update online status
void AIIntegrationManager::UpdateOnlineStatus(bool isOnline) {
    // Only update if status changed
    if (m_online != isOnline) {
        m_online = isOnline;
        
        // Update hybrid AI
        if (m_hybridAI) {
            m_hybridAI->HandleNetworkStatusChange(isOnline);
        }
        
        // Update available capabilities
        if (isOnline) {
            // Add online capabilities
            m_availableCapabilities |= GAME_ANALYSIS;
            m_availableCapabilities |= ONLINE_ENHANCED;
        } else {
            // Remove online capabilities
            m_availableCapabilities &= ~GAME_ANALYSIS;
            m_availableCapabilities &= ~ONLINE_ENHANCED;
        }
        
        // Log status change
        std::cout << "AIIntegrationManager: Network status changed to " 
                 << (isOnline ? "online" : "offline (AI unavailable)") << std::endl;
    }
}

// Report status update
void AIIntegrationManager::ReportStatus(const StatusUpdate& status) {
    // Log status
    if (status.m_isError) {
        std::cerr << "AIIntegrationManager: " << status.m_status << std::endl;
    } else {
        std::cout << "AIIntegrationManager: " << status.m_status 
                 << " (" << (status.m_progress * 100.0f) << "%)" << std::endl;
    }
    
    // Call callback if set
    if (m_statusCallback) {
        m_statusCallback(status);
    }
}

// Get optimal online mode
HybridAISystem::OnlineMode AIIntegrationManager::GetOptimalOnlineMode() const {
    // Get user preference
    AIConfig::OnlineMode configMode = m_config.GetOnlineMode();
    
    // If user explicitly set mode, respect it
    if (configMode != AIConfig::OnlineMode::Auto) {
        // Convert AIConfig::OnlineMode to HybridAISystem::OnlineMode
        switch (configMode) {
            case AIConfig::OnlineMode::PreferOnline:
                return HybridAISystem::OnlineMode::PreferOnline;
            case AIConfig::OnlineMode::PreferOnline:
                return HybridAISystem::OnlineMode::PreferOnline;
            case AIConfig::OnlineMode::OnlineOnly:
                return HybridAISystem::OnlineMode::OnlineOnly;
            case AIConfig::OnlineMode::OnlineOnly:
                return HybridAISystem::OnlineMode::OnlineOnly;
            default:
                break;
        }
    }
    
    // Auto mode - determine based on network status
    if (m_online) {
        // Check if on WiFi or cellular
        if (m_onlineService) {
            auto networkStatus = m_onlineService->GetNetworkStatus();
            if (networkStatus == OnlineService::NetworkStatus::ReachableViaWiFi) {
                return HybridAISystem::OnlineMode::PreferOnline; // WiFi, prefer online
            } else if (networkStatus == OnlineService::NetworkStatus::ReachableViaCellular) {
                return HybridAISystem::OnlineMode::PreferOnline; // Cellular — still online (offline removed)
            }
        }
        
        // Default online behavior if can't determine network type
        return HybridAISystem::OnlineMode::PreferOnline;
    } else {
        // No network — OnlineOnly will fail cleanly
        return HybridAISystem::OnlineMode::OnlineOnly;
    }
}

// Check if manager is initialized
bool AIIntegrationManager::IsInitialized() const {
    return m_initialized;
}

// Check if online mode is available
bool AIIntegrationManager::IsOnlineAvailable() const {
    return m_online;
}

// Get available AI capabilities
uint32_t AIIntegrationManager::GetAvailableCapabilities() const {
    return m_availableCapabilities;
}

// Check if a specific capability is available
bool AIIntegrationManager::HasCapability(AICapability capability) const {
    return (m_availableCapabilities & capability) != 0;
}

// Generate a script
void AIIntegrationManager::GenerateScript(const std::string& description, 
                                       const std::string& context,
                                       ScriptGenerationCallback callback,
                                       bool useOnline) {
    // Check if initialized
    if (!m_initialized) {
        if (callback) {
            callback("Error: AI system not initialized");
        }
        return;
    }
    
    // Check if capability available
    if (!(m_availableCapabilities & SCRIPT_GENERATION)) {
        if (callback) {
            callback("Error: Script generation capability not available");
        }
        return;
    }
    
    // Use hybrid AI for script generation
    m_hybridAI->GenerateScript(description, context, callback, useOnline && m_online);
}

// Debug a script
void AIIntegrationManager::DebugScript(const std::string& script,
                                    DebugResultCallback callback,
                                    bool useOnline) {
    // Check if initialized
    if (!m_initialized) {
        if (callback) {
            callback("Error: AI system not initialized");
        }
        return;
    }
    
    // Check if capability available
    if (!(m_availableCapabilities & SCRIPT_DEBUGGING)) {
        if (callback) {
            callback("Error: Script debugging capability not available");
        }
        return;
    }
    
    // Use hybrid AI for script debugging
    m_hybridAI->DebugScript(script, callback, useOnline && m_online);
}

// Process a general query
void AIIntegrationManager::ProcessQuery(const std::string& query,
                                     QueryResponseCallback callback,
                                     bool useOnline) {
    // Check if initialized
    if (!m_initialized) {
        if (callback) {
            callback("Error: AI system not initialized");
        }
        return;
    }
    
    // Use hybrid AI for query processing
    m_hybridAI->ProcessQuery(query, callback, useOnline && m_online);
}

// Report detection event to signature adaptation
void AIIntegrationManager::ReportDetection(const std::string& detectionType,
                                        const std::vector<uint8_t>& signature) {
    // Check if initialized
    if (!m_initialized || !m_signatureAdaptation) {
        return;
    }
    
    // Check if capability available
    if (!(m_availableCapabilities & SIGNATURE_ADAPTATION)) {
        return;
    }
    
    // Create detection event
    SignatureAdaptation::DetectionEvent event;
    event.m_detectionType = detectionType;
    event.m_signature = signature;
    event.m_timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    
    // Report detection
    m_signatureAdaptation->ReportDetection(event);
}

// Get signature adaptation system
std::shared_ptr<SignatureAdaptation> AIIntegrationManager::GetSignatureAdaptation() const {
    return m_signatureAdaptation;
}

// Get script assistant
std::shared_ptr<ScriptAssistant> AIIntegrationManager::GetScriptAssistant() const {
    return m_scriptAssistant;
}

// Get hybrid AI system
std::shared_ptr<HybridAISystem> AIIntegrationManager::GetHybridAI() const {
    return m_hybridAI;
}

// Get online service
std::shared_ptr<OnlineService> AIIntegrationManager::GetOnlineService() const {
    return m_onlineService;
}

// Set API key
void AIIntegrationManager::SetAPIKey(const std::string& apiKey) {
    // Update config
    m_config.SetAPIKey(apiKey);
    m_config.Save();
    
    // Update components
    if (m_onlineService) {
        m_onlineService->SetAPIKey(apiKey);
    }
    
    if (m_hybridAI) {
        m_hybridAI->SetAPIKey(apiKey);
    }
}

// Set online mode
void AIIntegrationManager::SetOnlineMode(::iOS::AIFeatures::HybridAISystem::OnlineMode mode) {
    // Update config - convert hybrid mode to config mode
    AIConfig::OnlineMode configMode;
    
    // Convert hybrid mode to config mode
    switch (mode) {
        case HybridAISystem::OnlineMode::Auto:
            configMode = AIConfig::OnlineMode::Auto;
            break;
        case HybridAISystem::OnlineMode::PreferOnline:
            configMode = AIConfig::OnlineMode::PreferOnline;
            break;
        case HybridAISystem::OnlineMode::PreferOnline:
            configMode = AIConfig::OnlineMode::PreferOnline;
            break;
        case HybridAISystem::OnlineMode::OnlineOnly:
            configMode = AIConfig::OnlineMode::OnlineOnly;
            break;
        case HybridAISystem::OnlineMode::OnlineOnly:
            configMode = AIConfig::OnlineMode::OnlineOnly;
            break;
        default:
            configMode = AIConfig::OnlineMode::Auto;
            break;
    }
    
    // Update config
    m_config.SetOnlineMode(configMode);
    m_config.Save();
    
    // Update components
    if (m_hybridAI) {
        m_hybridAI->SetOnlineMode(mode);
    }
}

// Get online mode
::iOS::AIFeatures::HybridAISystem::OnlineMode AIIntegrationManager::GetOnlineMode() const {
    // Convert config mode to hybrid mode
    switch (m_config.GetOnlineMode()) {
        case AIConfig::OnlineMode::Auto:
            return HybridAISystem::OnlineMode::Auto;
        case AIConfig::OnlineMode::PreferOnline:
            return HybridAISystem::OnlineMode::PreferOnline;
        case AIConfig::OnlineMode::PreferOnline:
            return HybridAISystem::OnlineMode::PreferOnline;
        case AIConfig::OnlineMode::OnlineOnly:
            return HybridAISystem::OnlineMode::OnlineOnly;
        case AIConfig::OnlineMode::OnlineOnly:
            return HybridAISystem::OnlineMode::OnlineOnly;
        default:
            return HybridAISystem::OnlineMode::Auto;
    }
}

// Set model quality
void AIIntegrationManager::SetModelQuality(AIConfig::ModelQuality quality) {
    // Update config
    m_config.SetModelQuality(quality);
    m_config.Save();
    
    // Notify user that changes require restart
    ReportStatus(StatusUpdate("Model quality updated. Restart required for changes to take effect.", 1.0f));
}

// Get model quality
AIConfig::ModelQuality AIIntegrationManager::GetModelQuality() const {
    return m_config.GetModelQuality();
}

// Handle memory warning
void AIIntegrationManager::HandleMemoryWarning() {
    // Log warning
    std::cout << "AIIntegrationManager: Handling memory warning" << std::endl;
    
    // Forward to components
    if (m_hybridAI) {
        m_hybridAI->HandleMemoryWarning();
    }
    
    if (m_scriptAssistant) {
        m_scriptAssistant->ReleaseUnusedResources();
    }
    
    if (m_signatureAdaptation) {
        m_signatureAdaptation->ReleaseUnusedResources();
    }
}

// Handle app entering foreground
void AIIntegrationManager::HandleAppForeground() {
    // Log event
    std::cout << "AIIntegrationManager: Handling app foreground" << std::endl;
    
    // Check network status
    if (m_onlineService) {
        bool isOnline = m_onlineService->IsNetworkReachable();
        UpdateOnlineStatus(isOnline);
    }
    
    // Forward to components if needed
    if (m_hybridAI) {
        // Nothing to do currently
    }
}

// Handle app entering background
void AIIntegrationManager::HandleAppBackground() {
    // Log event
    std::cout << "AIIntegrationManager: Handling app background" << std::endl;
    
    // Save config
    m_config.Save();
    
    // Release resources if needed
    // Use a direct check instead of accessing private GetOption
    if (true) { // Release memory by default
        HandleMemoryWarning();
    }
}

// Handle network status change
void AIIntegrationManager::HandleNetworkStatusChange(bool isOnline) {
    UpdateOnlineStatus(isOnline);
}

// Get memory usage
uint64_t AIIntegrationManager::GetMemoryUsage() const {
    uint64_t total = 0;
    
    if (m_hybridAI) {
        total += m_hybridAI->GetMemoryUsage();
    }
    
    if (m_scriptAssistant) {
        total += m_scriptAssistant->GetMemoryUsage();
    }
    
    if (m_signatureAdaptation) {
        total += m_signatureAdaptation->GetMemoryUsage();
    }
    
    return total;
}

// Save configuration changes
bool AIIntegrationManager::SaveConfig() {
    return m_config.Save();
}

} // namespace AIFeatures
} // namespace iOS

// C interface for Objective-C and Swift
extern "C" {

void* AI_GetSharedManager() {
    return &iOS::AIFeatures::AIIntegrationManager::GetSharedInstance();
}

bool AI_Initialize(const char* apiKey, void (*statusCallback)(const char*, float, bool)) {
    auto& manager = iOS::AIFeatures::AIIntegrationManager::GetSharedInstance();
    
    // Create status callback wrapper
    std::function<void(const iOS::AIFeatures::AIIntegrationManager::StatusUpdate&)> callback = nullptr;
    
    if (statusCallback) {
        callback = [statusCallback](const iOS::AIFeatures::AIIntegrationManager::StatusUpdate& status) {
            statusCallback(status.m_status.c_str(), status.m_progress, status.m_isError);
        };
    }
    
    // Initialize manager
    return manager.Initialize(apiKey ? apiKey : "", callback);
}

bool AI_IsInitialized() {
    auto& manager = iOS::AIFeatures::AIIntegrationManager::GetSharedInstance();
    return manager.IsInitialized();
}

bool AI_IsOnlineAvailable() {
    auto& manager = iOS::AIFeatures::AIIntegrationManager::GetSharedInstance();
    return manager.IsOnlineAvailable();
}

void AI_GenerateScript(const char* description, const char* context, void (*callback)(const char*), bool useOnline) {
    auto& manager = iOS::AIFeatures::AIIntegrationManager::GetSharedInstance();
    
    // Create callback wrapper
    std::function<void(const std::string&)> callbackWrapper = nullptr;
    
    if (callback) {
        callbackWrapper = [callback](const std::string& script) {
            callback(script.c_str());
        };
    }
    
    // Generate script
    manager.GenerateScript(
        description ? description : "",
        context ? context : "",
        callbackWrapper,
        useOnline
    );
}

void AI_DebugScript(const char* script, void (*callback)(const char*), bool useOnline) {
    auto& manager = iOS::AIFeatures::AIIntegrationManager::GetSharedInstance();
    
    // Create callback wrapper
    std::function<void(const std::string&)> callbackWrapper = nullptr;
    
    if (callback) {
        callbackWrapper = [callback](const std::string& result) {
            callback(result.c_str());
        };
    }
    
    // Debug script
    manager.DebugScript(
        script ? script : "",
        callbackWrapper,
        useOnline
    );
}

void AI_ProcessQuery(const char* query, void (*callback)(const char*), bool useOnline) {
    auto& manager = iOS::AIFeatures::AIIntegrationManager::GetSharedInstance();
    
    // Create callback wrapper
    std::function<void(const std::string&)> callbackWrapper = nullptr;
    
    if (callback) {
        callbackWrapper = [callback](const std::string& response) {
            callback(response.c_str());
        };
    }
    
    // Process query
    manager.ProcessQuery(
        query ? query : "",
        callbackWrapper,
        useOnline
    );
}

void AI_ReportDetection(const char* detectionType, const void* signature, int signatureLength) {
    auto& manager = iOS::AIFeatures::AIIntegrationManager::GetSharedInstance();
    
    // Convert signature to vector
    std::vector<uint8_t> signatureData;
    if (signature && signatureLength > 0) {
        const uint8_t* bytes = static_cast<const uint8_t*>(signature);
        signatureData.assign(bytes, bytes + signatureLength);
    }
    
    // Report detection
    manager.ReportDetection(
        detectionType ? detectionType : "",
        signatureData
    );
}

void AI_SetAPIKey(const char* apiKey) {
    auto& manager = iOS::AIFeatures::AIIntegrationManager::GetSharedInstance();
    manager.SetAPIKey(apiKey ? apiKey : "");
}

void AI_SetOnlineMode(int mode) {
    auto& manager = iOS::AIFeatures::AIIntegrationManager::GetSharedInstance();
    
    // Convert int to HybridAISystem::OnlineMode
    iOS::AIFeatures::HybridAISystem::OnlineMode onlineMode;
    switch (mode) {
        case 0:
            onlineMode = iOS::AIFeatures::HybridAISystem::OnlineMode::Auto;
            break;
        case 1:
            onlineMode = iOS::AIFeatures::HybridAISystem::OnlineMode::PreferOnline;
            break;
        case 2:
            onlineMode = iOS::AIFeatures::HybridAISystem::OnlineMode::PreferOnline;
            break;
        case 3:
            onlineMode = iOS::AIFeatures::HybridAISystem::OnlineMode::OnlineOnly;
            break;
        case 4:
            onlineMode = iOS::AIFeatures::HybridAISystem::OnlineMode::OnlineOnly;
            break;
        default:
            onlineMode = iOS::AIFeatures::HybridAISystem::OnlineMode::Auto;
            break;
    }
    
    manager.SetOnlineMode(onlineMode);
}

int AI_GetOnlineMode() {
    auto& manager = iOS::AIFeatures::AIIntegrationManager::GetSharedInstance();
    
    // Convert HybridAISystem::OnlineMode to int
    switch (manager.GetOnlineMode()) {
        case iOS::AIFeatures::HybridAISystem::OnlineMode::Auto:
            return 0;
        case iOS::AIFeatures::HybridAISystem::OnlineMode::PreferOnline:
            return 1;
        case iOS::AIFeatures::HybridAISystem::OnlineMode::PreferOnline:
            return 2;
        case iOS::AIFeatures::HybridAISystem::OnlineMode::OnlineOnly:
            return 3;
        case iOS::AIFeatures::HybridAISystem::OnlineMode::OnlineOnly:
            return 4;
        default:
            return 0;
    }
}

void AI_SetModelQuality(int quality) {
    auto& manager = iOS::AIFeatures::AIIntegrationManager::GetSharedInstance();
    
    // Convert int to ModelQuality
    iOS::AIFeatures::AIConfig::ModelQuality modelQuality;
    switch (quality) {
        case 0:
            modelQuality = iOS::AIFeatures::AIConfig::ModelQuality::Low;
            break;
        case 1:
            modelQuality = iOS::AIFeatures::AIConfig::ModelQuality::Medium;
            break;
        case 2:
            modelQuality = iOS::AIFeatures::AIConfig::ModelQuality::High;
            break;
        default:
            modelQuality = iOS::AIFeatures::AIConfig::ModelQuality::Medium;
            break;
    }
    
    manager.SetModelQuality(modelQuality);
}

int AI_GetModelQuality() {
    auto& manager = iOS::AIFeatures::AIIntegrationManager::GetSharedInstance();
    
    // Convert ModelQuality to int
    switch (manager.GetModelQuality()) {
        case iOS::AIFeatures::AIConfig::ModelQuality::Low:
            return 0;
        case iOS::AIFeatures::AIConfig::ModelQuality::Medium:
            return 1;
        case iOS::AIFeatures::AIConfig::ModelQuality::High:
            return 2;
        default:
            return 1;
    }
}

void AI_HandleMemoryWarning() {
    auto& manager = iOS::AIFeatures::AIIntegrationManager::GetSharedInstance();
    manager.HandleMemoryWarning();
}

void AI_HandleAppForeground() {
    auto& manager = iOS::AIFeatures::AIIntegrationManager::GetSharedInstance();
    manager.HandleAppForeground();
}

void AI_HandleAppBackground() {
    auto& manager = iOS::AIFeatures::AIIntegrationManager::GetSharedInstance();
    manager.HandleAppBackground();
}

void AI_HandleNetworkStatusChange(bool isOnline) {
    auto& manager = iOS::AIFeatures::AIIntegrationManager::GetSharedInstance();
    manager.HandleNetworkStatusChange(isOnline);
}

uint64_t AI_GetMemoryUsage() {
    auto& manager = iOS::AIFeatures::AIIntegrationManager::GetSharedInstance();
    return manager.GetMemoryUsage();
}

bool AI_SaveConfig() {
    auto& manager = iOS::AIFeatures::AIIntegrationManager::GetSharedInstance();
    return manager.SaveConfig();
}

} // extern "C"
