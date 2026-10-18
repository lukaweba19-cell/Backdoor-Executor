#include "ios_compat.h"
#include "AISystemInitializer.h"
#include "AIConfig.h"
#include <iostream>

namespace iOS {
namespace AIFeatures {

AISystemInitializer* AISystemInitializer::s_instance = nullptr;

AISystemInitializer* AISystemInitializer::GetInstance() {
    if (!s_instance) s_instance = new AISystemInitializer();
    return s_instance;
}

bool AISystemInitializer::Initialize(ProgressCallback progress) {
    if (m_initialized) {
        if (progress) progress(1.0f, "Already initialized");
        return true;
    }
    if (progress) progress(0.2f, "Loading AI config");
    auto& cfg = AIConfig::GetSharedInstance();
    if (!cfg.IsInitialized()) cfg.Initialize();
    if (progress) progress(1.0f, "Online AI config ready (no local models)");
    m_initialized = true;
    std::cout << "AISystemInitializer: online-only (local training removed)" << std::endl;
    return true;
}

} // namespace AIFeatures
} // namespace iOS
