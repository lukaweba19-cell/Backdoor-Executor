
#include "objc_isolation.h"
#pragma once

#include <functional>

// Forward declarations for vulnerability detection
namespace iOS {
    namespace AIFeatures {
        class ScriptAssistant;
        class SignatureAdaptation;
        
        namespace VulnerabilityDetection {
            class VulnerabilityDetector;
            struct Vulnerability;
        }
    }
    
    namespace UI {
        class MainViewController;
        class VulnerabilityViewController;
    }
}

/**
 * C interface for AI integration
 * 
 * These functions provide a simple C interface for integrating AI features
 * into your Objective-C/Swift code. Use these in your app delegate and
 * view controllers to initialize and interact with the AI systems.
 */
#ifdef __cplusplus
extern "C" {
#endif

/**
 * Initialize the AI system
 * 
 * @param progressCallback Function to call with progress updates (0.0-1.0)
 * @return Opaque pointer to the AI integration (use in future calls)
 */
void* InitializeAI(void (*progressCallback)(float));

/**
 * Set up AI with the main UI
 * 
 * @param integration Opaque pointer from InitializeAI
 * @param viewController Pointer to MainViewController shared_ptr
 */
void SetupAIWithUI(void* integration, void* viewController);

/**
 * Get the script assistant
 * 
 * @param integration Opaque pointer from InitializeAI
 * @return Pointer to ScriptAssistant shared_ptr
 */
void* GetScriptAssistant(void* integration);

/**
 * Get the signature adaptation system
 * 
 * @param integration Opaque pointer from InitializeAI
 * @return Pointer to SignatureAdaptation shared_ptr
 */
void* GetSignatureAdaptation(void* integration);

/**
 * Get memory usage of AI components
 * 
 * @param integration Opaque pointer from InitializeAI
 * @return Memory usage in bytes
 */
uint64_t GetAIMemoryUsage(void* integration);

/**
 * Handle app entering foreground
 * 
 * @param integration Opaque pointer from InitializeAI
 */
void HandleAppForeground(void* integration);

/**
 * Handle app memory warning
 * 
 * @param integration Opaque pointer from InitializeAI
 */
void HandleAppMemoryWarning(void* integration);

/**
 * Process a user query with the AI assistant
 * 
 * @param integration Opaque pointer from InitializeAI
 * @param query User query
 * @param callback Function to call with response
 */
void ProcessAIQuery(void* integration, const char* query, void (*callback)(const char*));

/**
 * Generate a script using AI
 * 
 * @param integration Opaque pointer from InitializeAI
 * @param description Script description
 * @param callback Function to call with generated script
 */
void GenerateScript(void* integration, const char* description, void (*callback)(const char*));

/**
 * Debug a script using AI
 * 
 * @param integration Opaque pointer from InitializeAI
 * @param script Script to debug
 * @param callback Function to call with debug results
 */
void DebugScript(void* integration, const char* script, void (*callback)(const char*));

#ifdef __cplusplus
} // extern "C"
#endif

// C++ interface for AIIntegration - include this only in C++ files
#ifdef __cplusplus

namespace iOS {
namespace AIFeatures {

/**
 * C++ AI Integration Interface
 * 
 * Higher-level C++ interface for AI integration.
 * This is a thin wrapper around the C interface and
 * provides a more C++-friendly API.
 */
class AIIntegrationInterface {
private:
    void* m_integration;
    
public:
    /**
     * Constructor
     */
    AIIntegrationInterface()
        : m_integration(nullptr) {
    }
    
    /**
     * Initialize AI with progress callback
     * 
     * @param progressCallback Function to call with progress updates
     * @return True if initialization succeeded
     */
    bool Initialize(std::function<void(float)> progressCallback = nullptr) {
        // Create a static function to bridge to the std::function
        static std::function<void(float)> s_progressCallback;
        s_progressCallback = progressCallback;
        
        static auto progressBridge = [](float progress) {
            if (s_progressCallback) {
                s_progressCallback(progress);
            }
        };
        
        m_integration = InitializeAI(progressCallback ? progressBridge : nullptr);
        return m_integration != nullptr;
    }
    
    /**
     * Set up with UI
     * 
     * @param viewController Main view controller
     */
    void SetupUI(std::shared_ptr<UI::MainViewController> viewController) {
        if (m_integration) {
            SetupAIWithUI(m_integration, &viewController);
        }
    }
    
    /**
     * Get script assistant
     * 
     * @return Script assistant or nullptr if not initialized
     */
    std::shared_ptr<ScriptAssistant> GetScriptAssistant() {
        if (!m_integration) return nullptr;
        
        void* ptr = ::GetScriptAssistant(m_integration);
        return ptr ? *static_cast<std::shared_ptr<ScriptAssistant>*>(ptr) : nullptr;
    }
    
    /**
     * Get signature adaptation
     * 
     * @return Signature adaptation or nullptr if not initialized
     */
    std::shared_ptr<SignatureAdaptation> GetSignatureAdaptation() {
        if (!m_integration) return nullptr;
        
        void* ptr = ::GetSignatureAdaptation(m_integration);
        return ptr ? *static_cast<std::shared_ptr<SignatureAdaptation>*>(ptr) : nullptr;
    }
    
    /**
     * Get memory usage
     * 
     * @return Memory usage in bytes
     */
    uint64_t GetMemoryUsage() {
        return m_integration ? GetAIMemoryUsage(m_integration) : 0;
    }
    
    /**
     * Handle app foreground
     */
    void HandleForeground() {
        if (m_integration) {
            HandleAppForeground(m_integration);
        }
    }
    
    /**
     * Handle memory warning
     */
    void HandleMemoryWarning() {
        if (m_integration) {
            HandleAppMemoryWarning(m_integration);
        }
    }
    
    /**
     * Process a query
     * 
     * @param query User query
     * @param callback Function to call with response
     */
    void ProcessQuery(const std::string& query, std::function<void(const std::string&)> callback) {
        if (!m_integration) return;
        
        // Create a static function to bridge to the std::function
        static std::function<void(const std::string&)> s_callback;
        s_callback = callback;
        
        static auto callbackBridge = [](const char* response) {
            if (s_callback) {
                s_callback(response);
            }
        };
        
        ProcessAIQuery(m_integration, query.c_str(), callbackBridge);
    }
    
    /**
     * Check if AI is initialized
     * 
     * @return True if initialized
     */
    bool IsInitialized() const {
        return m_integration != nullptr;
    }
};

} // namespace AIFeatures
} // namespace iOS

#endif // __cplusplus
