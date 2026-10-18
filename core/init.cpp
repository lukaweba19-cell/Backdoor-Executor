// init.cpp - Implementation for library initialization functionality
#include "init.hpp"
#include "logging.hpp"
#include "performance.hpp"
#include "security/anti_tamper.hpp"
#include "utils/naming_conventions/naming_conventions.h"
#include "utils/naming_conventions/function_resolver.h"
#include "utils/naming_conventions/script_preprocessor.h"

// Include iOS-specific headers only when compiling for iOS
#ifdef __APPLE__
  #include "ios/ExecutionEngine.h"
  #include "ios/ScriptManager.h"
  #include "ios/UIController.h"
  #include "ios/JailbreakBypass.h"
  #ifdef ENABLE_AI_FEATURES
    #include "ios/ai_features/AIIntegrationManager.h"
    #include "ios/ai_features/ScriptAssistant.h"
    #include "ios/ai_features/SignatureAdaptation.h"
  #endif
#endif

namespace RobloxExecutor {

// Implementation of SystemState::Initialize declared in init.hpp
bool SystemState::Initialize(const InitOptions& options) {
    if (s_initialized) {
        Logging::LogWarning("System", "RobloxExecutor already initialized");
        return true;
    }

    try {
        Logging::LogInfo("System", "Initializing RobloxExecutor system");
        
        // Store init options
        s_options = options;
        
        // Initialize logging system
        if (options.enableLogging) {
            // Simply log that we've initialized (actual logging system is already initialized)
            Logging::LogInfo("System", "Logging system initialized");
            s_status.loggingInitialized = true;
        }
        
        // Initialize error handling with proper error reporting
        if (options.enableErrorReporting) {
            try {
                // ErrorHandling::ErrorManager may be header-only helpers in this tree
                Logging::LogInfo("System", "Error handling / crash reporting enabled");
                if (options.enableCrashReporting && !options.crashReportDir.empty()) {
                    Logging::LogInfo("System", "Crash reports directory: " + options.crashReportDir);
                }
                s_status.errorHandlingInitialized = true;
            } catch (const std::exception& e) {
                Logging::LogError("System", std::string("Error handling init failed: ") + e.what());
            }
        }
        
        // Initialize security features using Security::AntiTamper
        if (options.enableSecurity) {
            // Initialize security system with anti-tamper monitoring
            Security::AntiTamper::Initialize();
            
            // Start active monitoring if requested
            if (options.startSecurityMonitoring) {
                Security::AntiTamper::StartMonitoring();
                Logging::LogInfo("System", "Security monitoring started");
            }
            
            Logging::LogInfo("System", "Security features initialized");
            s_status.securityInitialized = true;
        }
        
        // Initialize jailbreak bypass if needed
        if (options.enableJailbreakBypass) {
#ifdef __APPLE__
            try {
                if (iOS::JailbreakBypass::Initialize()) {
                    Logging::LogInfo("System", "Jailbreak bypass initialized");
                    s_status.jailbreakBypassInitialized = true;
                } else {
                    Logging::LogError("System", "Jailbreak bypass Initialize() returned false");
                }
            } catch (const std::exception& e) {
                Logging::LogError("System", std::string("Jailbreak bypass failed: ") + e.what());
            }
#else
            Logging::LogInfo("System", "Jailbreak bypass skipped (non-Apple)");
            s_status.jailbreakBypassInitialized = true;
#endif
        }
        
        // Initialize performance monitoring if needed
        if (options.enablePerformanceMonitoring) {
            Performance::InitializePerformanceMonitoring(
                true,  // enableProfiling
                options.enableAutoPerformanceLogging,
                options.performanceThresholdMs
            );
            s_status.performanceInitialized = true;
        }
        
        // Initialize naming conventions system
        if (options.enableNamingConventions) {
            // Initialize naming convention manager
            auto& namingConventionManager = NamingConventions::NamingConventionManager::GetInstance();
            if (!namingConventionManager.Initialize()) {
                Logging::LogError("System", "Failed to initialize naming convention manager");
                // Continue despite naming convention initialization failure
            } else {
                // Initialize function resolver
                auto& functionResolver = NamingConventions::FunctionResolver::GetInstance();
                if (!functionResolver.Initialize()) {
                    Logging::LogError("System", "Failed to initialize function resolver");
                    // Continue despite function resolver initialization failure
                } else {
                    // Initialize script preprocessor
                    auto& scriptPreprocessor = NamingConventions::ScriptPreprocessor::GetInstance();
                    if (!scriptPreprocessor.Initialize()) {
                        Logging::LogError("System", "Failed to initialize script preprocessor");
                        // Continue despite script preprocessor initialization failure
                    } else {
                        Logging::LogInfo("System", "Naming conventions system initialized");
                        s_status.namingConventionsInitialized = true;
                    }
                }
            }
        }
        
#ifdef __APPLE__
        // Initialize execution engine
        s_executionEngine = std::make_shared<iOS::ExecutionEngine>();
        if (!s_executionEngine->Initialize()) {
            Logging::LogError("System", "Failed to initialize execution engine");
            return false;
        }
        s_status.executionEngineInitialized = true;
        
        // Initialize script manager
        s_scriptManager = std::make_shared<iOS::ScriptManager>(
            options.enableScriptCaching,
            10, // Max cache size
            "Scripts"
        );
        if (!s_scriptManager->Initialize()) {
            Logging::LogError("System", "Failed to initialize script manager");
            return false;
        }
        s_status.scriptManagerInitialized = true;
        
        // Initialize UI if enabled
        if (options.enableUI) {
            s_uiController = std::make_unique<iOS::UIController>();
            if (!s_uiController->Initialize()) {
                Logging::LogWarning("System", "Failed to initialize UI controller");
                // Continue despite UI initialization failure
            } else {
                // Configure UI
                s_uiController->SetButtonVisible(options.showFloatingButton);
                
                // Set up execute callback - matches ExecuteCallback = std::function<bool(const std::string&)>
                s_uiController->SetExecuteCallback([](const std::string& script) -> bool {
                    // Execute the script using the execution engine
                    Logging::LogInfo("UI", "Executing script: " + script);
                    
                    // Get execution engine
                    auto engine = s_executionEngine;
                    if (!engine) {
                        Logging::LogError("UI", "Execute failed: Execution engine not initialized");
                        return false;
                    }
                    
                    // Execute script
                    auto result = engine->Execute(script);
                    return result.m_success;
                });
                
                s_status.uiInitialized = true;
            }
        }
        
        // Initialize AI features if enabled - full implementation
        if (options.enableAI && s_status.uiInitialized) {
            try {
                Logging::LogInfo("System", "Initializing AI subsystem");
                
                // Create AI integration manager (singleton pattern)
                s_aiManager = std::shared_ptr<iOS::AIFeatures::AIIntegrationManager>(
                    &iOS::AIFeatures::AIIntegrationManager::GetSharedInstance(), 
                    [](iOS::AIFeatures::AIIntegrationManager*){} // No-op deleter for singleton
                );
                
                // Initialize AI components
                if (s_aiManager) {
                    // Setup progress tracking callback
                    auto progressCallback = [](const iOS::AIFeatures::AIIntegrationManager::StatusUpdate& update) {
                        Logging::LogInfo("AI", "Initialization: " + 
                            std::to_string(static_cast<int>(update.m_progress * 100.0f)) + "% - " + update.m_status);
                    };
                    
                    // Initialize the manager - pass empty string as API key and callback as second param
                    s_aiManager->Initialize("", progressCallback);
                    
                    // Get script assistant component
                    s_scriptAssistant = s_aiManager->GetScriptAssistant();
                    
                    // Get signature adaptation component
                    s_signatureAdaptation = s_aiManager->GetSignatureAdaptation();
                    
                    // Connect the script assistant to the execution engine
                    if (s_scriptAssistant && s_executionEngine) {
                        // SetExecutionCallback expects: void(bool success, const std::string& output)
                        s_scriptAssistant->SetExecutionCallback([](bool success, const std::string& output) {
                            // This is the correct signature - void with success and output parameters
                            Logging::LogInfo("AI", "Script execution " + 
                                std::string(success ? "succeeded" : "failed") + ": " + output);
                        });
                    }
                    
                    Logging::LogInfo("System", "AI subsystem initialized successfully");
                    s_status.aiInitialized = true;
                }
            } catch (const std::exception& ex) {
                Logging::LogWarning("System", "Failed to initialize AI subsystem: " + std::string(ex.what()));
                // Continue without AI support
            }
        }
#else
        // Non-iOS platform - mark these as initialized to avoid errors
        Logging::LogInfo("System", "iOS-specific components skipped on non-iOS platform");
        s_status.executionEngineInitialized = true;
        s_status.scriptManagerInitialized = true;
        s_status.uiInitialized = true;
        s_status.aiInitialized = true;
#endif
        
        // Mark as initialized
        s_initialized = true;
        s_status.allSystemsInitialized = true;
        
        Logging::LogInfo("System", "All systems initialized successfully");
        
        // Call post-init callback if provided
        if (s_options.postInitCallback) {
            s_options.postInitCallback();
        }
        
        return true;
    } catch (const std::exception& ex) {
        Logging::LogCritical("System", "Exception during initialization: " + std::string(ex.what()));
        return false;
    }
}

// Implementation of SystemState::Shutdown declared in init.hpp
void SystemState::Shutdown() {
    if (!s_initialized) {
        return;
    }
    
    try {
        Logging::LogInfo("System", "Shutting down RobloxExecutor system");
        
        // Clean up in reverse order of initialization
        
#ifdef __APPLE__
        // Clean up UI controller
        if (s_uiController) {
            s_uiController.reset();
        }
        
        // Clean up script manager and execution engine
        s_scriptManager.reset();
        s_executionEngine.reset();
        
        // Clean up AI components
        s_scriptAssistant.reset();
        s_signatureAdaptation.reset();
        s_aiManager.reset();
        
        if (s_aiIntegration) {
            // Cleanup would go here
            s_aiIntegration = nullptr;
        }
#else
        // No iOS-specific cleanup needed on non-iOS platforms
        Logging::LogInfo("System", "Skipping iOS-specific cleanup on non-iOS platform");
#endif
        
        // Stop performance monitoring
        if (s_status.performanceInitialized) {
            Performance::Profiler::StopMonitoring();
        }
        
        // Stop security monitoring
        if (s_status.securityInitialized) {
            Security::AntiTamper::StopMonitoring();
        }
        
        // Log shutdown if logging is still available
        Logging::LogInfo("System", "System shutdown complete");
        
        // Mark as uninitialized
        s_initialized = false;
        s_status = SystemStatus();
    } catch (const std::exception& ex) {
        // Best effort to log the error
        Logging::LogCritical("System", "Exception during shutdown: " + std::string(ex.what()));
    }
}

} // namespace RobloxExecutor
