#pragma once
#include "objc_isolation.h"
#include <string>
#include <memory>
#include <functional>

namespace iOS {
namespace AIFeatures {

/**
 * Minimal initializer shell — local models/training removed.
 * Real AI init goes through AIIntegration / HybridAISystem + AIConfig.
 */
class AISystemInitializer {
public:
    using ProgressCallback = std::function<void(float, const std::string&)>;

    static AISystemInitializer* GetInstance();

    bool Initialize(ProgressCallback progress = nullptr);
    bool IsInitialized() const { return m_initialized; }
    bool AreModelsAvailableOffline() const { return false; }

private:
    AISystemInitializer() : m_initialized(false) {}
    bool m_initialized;
    static AISystemInitializer* s_instance;
};

} // namespace AIFeatures
} // namespace iOS
