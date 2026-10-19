#include "ios_compat.h"
#include "AIIntegration.h"
#include "AIConfig.h"
#include "HybridAISystem.h"
#include "ScriptAssistant.h"
#include "SignatureAdaptation.h"
#include "OnlineService.h"
#include "ui/MainViewController.h"
#include "ui/VulnerabilityViewController.h"
#include "vulnerability_detection/VulnerabilityDetector.h"
#include <iostream>
#include <string>
#include <memory>
#include <mutex>

namespace iOS {
namespace AIFeatures {

class AIIntegration {
public:
    static AIIntegration* GetSharedInstance() {
        static AIIntegration instance;
        return &instance;
    }

    bool Initialize(std::function<void(float)> progressCallback = nullptr) {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (m_aiInitialized) {
            if (progressCallback) progressCallback(1.0f);
            return true;
        }

        if (progressCallback) progressCallback(0.1f);

        auto& config = AIConfig::GetSharedInstance();
        if (!config.IsInitialized()) {
            config.Initialize();
        }

        if (progressCallback) progressCallback(0.3f);

        std::string endpoint = config.GetAPIEndpoint();
        std::string apiKey = config.GetAPIKey();
        if (endpoint.empty()) endpoint = "https://openrouter.ai/api/v1";

        m_hybridAI = std::make_shared<HybridAISystem>();
        bool ok = m_hybridAI->Initialize("", endpoint, apiKey,
                                         HybridAISystem::OnlineMode::OnlineOnly);
        if (!ok) {
            std::cerr << "AIIntegration: HybridAISystem init failed" << std::endl;
        }

        if (progressCallback) progressCallback(0.6f);

        m_scriptAssistant = std::make_shared<ScriptAssistant>();
        m_scriptAssistant->Initialize();

        m_signatureAdaptation = std::make_shared<SignatureAdaptation>();
        m_signatureAdaptation->SetHybridAI(m_hybridAI);
        m_signatureAdaptation->Initialize();

        if (progressCallback) progressCallback(0.85f);

        m_vulnerabilityDetector = std::make_shared<VulnerabilityDetection::VulnerabilityDetector>();
        m_vulnerabilityDetector->SetHybridAI(m_hybridAI);
        m_vulnerabilityDetector->Initialize();

        m_aiInitialized = true;
        if (progressCallback) progressCallback(1.0f);

        std::cout << "AIIntegration: Online AI system initialized" << std::endl;
        return true;
    }

    void SetupWithUI(std::shared_ptr<UI::MainViewController> mainVC) {
        m_mainViewController = mainVC;
    }

    std::shared_ptr<ScriptAssistant> GetScriptAssistant() { return m_scriptAssistant; }
    std::shared_ptr<SignatureAdaptation> GetSignatureAdaptation() { return m_signatureAdaptation; }
    std::shared_ptr<HybridAISystem> GetHybridAI() { return m_hybridAI; }

    uint64_t GetMemoryUsage() const {
        return 0; // Online-only; no local model memory
    }

    void HandleForeground() {
        // Re-check network is handled inside HybridAI on each request
    }

    void HandleMemoryWarning() {
        m_isInLowMemoryMode = true;
    }

    void ProcessQuery(const std::string& query, std::function<void(const std::string&)> callback) {
        if (!m_aiInitialized || !m_hybridAI) {
            if (callback) callback("AI system not initialized");
            return;
        }
        m_hybridAI->ProcessQuery(query, [callback](const HybridAISystem::AIResponse& r) {
            if (callback) callback(r.m_success ? r.m_content : ("Error: " + r.m_errorMessage));
        });
    }

    void GenerateScript(const std::string& description, std::function<void(const std::string&)> callback) {
        if (!m_aiInitialized || !m_hybridAI) {
            if (callback) callback("AI system not initialized");
            return;
        }
        m_hybridAI->GenerateScript(description, "", [callback](const HybridAISystem::AIResponse& r) {
            if (!callback) return;
            if (!r.m_success) {
                callback("Error: " + r.m_errorMessage);
                return;
            }
            if (!r.m_scriptCode.empty()) {
                callback(r.m_scriptCode);
            } else {
                callback(r.m_content);
            }
        });
    }

    void DebugScript(const std::string& script, std::function<void(const std::string&)> callback) {
        if (!m_aiInitialized || !m_hybridAI) {
            if (callback) callback("AI system not initialized");
            return;
        }
        m_hybridAI->DebugScript(script, [callback](const HybridAISystem::AIResponse& r) {
            if (callback) callback(r.m_success ? r.m_content : ("Error: " + r.m_errorMessage));
        });
    }

private:
    AIIntegration()
        : m_aiInitialized(false), m_isInLowMemoryMode(false) {}

    std::shared_ptr<HybridAISystem> m_hybridAI;
    std::shared_ptr<ScriptAssistant> m_scriptAssistant;
    std::shared_ptr<SignatureAdaptation> m_signatureAdaptation;
    std::shared_ptr<UI::MainViewController> m_mainViewController;
    std::shared_ptr<UI::VulnerabilityViewController> m_vulnerabilityViewController;
    std::shared_ptr<VulnerabilityDetection::VulnerabilityDetector> m_vulnerabilityDetector;

    bool m_aiInitialized;
    bool m_isInLowMemoryMode;
    std::mutex m_mutex;
};

} // namespace AIFeatures
} // namespace iOS

// ---------- C API ----------
using iOS::AIFeatures::AIIntegration;

extern "C" {

void* InitializeAI(void (*progressCallback)(float)) {
    auto* integration = AIIntegration::GetSharedInstance();
    std::function<void(float)> cb;
    if (progressCallback) {
        cb = [progressCallback](float p) { progressCallback(p); };
    }
    integration->Initialize(cb);
    return static_cast<void*>(integration);
}

void SetupAIWithUI(void* integration, void* viewController) {
    if (!integration) return;
    auto* ai = static_cast<AIIntegration*>(integration);
    if (viewController) {
        auto* vcPtr = static_cast<std::shared_ptr<iOS::UI::MainViewController>*>(viewController);
        if (vcPtr) ai->SetupWithUI(*vcPtr);
    }
}

void* GetScriptAssistant(void* integration) {
    if (!integration) return nullptr;
    auto* ai = static_cast<AIIntegration*>(integration);
    // Return address of shared_ptr held inside — callers must not free
    static std::shared_ptr<iOS::AIFeatures::ScriptAssistant> holder;
    holder = ai->GetScriptAssistant();
    return holder ? static_cast<void*>(&holder) : nullptr;
}

void* GetSignatureAdaptation(void* integration) {
    if (!integration) return nullptr;
    auto* ai = static_cast<AIIntegration*>(integration);
    static std::shared_ptr<iOS::AIFeatures::SignatureAdaptation> holder;
    holder = ai->GetSignatureAdaptation();
    return holder ? static_cast<void*>(&holder) : nullptr;
}

uint64_t GetAIMemoryUsage(void* integration) {
    if (!integration) return 0;
    return static_cast<AIIntegration*>(integration)->GetMemoryUsage();
}

void HandleAppForeground(void* integration) {
    if (!integration) return;
    static_cast<AIIntegration*>(integration)->HandleForeground();
}

void HandleAppMemoryWarning(void* integration) {
    if (!integration) return;
    static_cast<AIIntegration*>(integration)->HandleMemoryWarning();
}

void ProcessAIQuery(void* integration, const char* query, void (*callback)(const char*)) {
    if (!integration || !query) return;
    auto* ai = static_cast<AIIntegration*>(integration);
    ai->ProcessQuery(query, [callback](const std::string& response) {
        if (callback) callback(response.c_str());
    });
}

void GenerateScript(void* integration, const char* description, void (*callback)(const char*)) {
    if (!integration || !description) return;
    auto* ai = static_cast<AIIntegration*>(integration);
    ai->GenerateScript(description, [callback](const std::string& script) {
        if (callback) callback(script.c_str());
    });
}

void DebugScript(void* integration, const char* script, void (*callback)(const char*)) {
    if (!integration || !script) return;
    auto* ai = static_cast<AIIntegration*>(integration);
    ai->DebugScript(script, [callback](const std::string& result) {
        if (callback) callback(result.c_str());
    });
}

} // extern "C"
