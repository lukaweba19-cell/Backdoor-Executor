#include "ios_compat.h"
#include "SignatureAdaptation.h"
#include "HybridAISystem.h"
#include "AIConfig.h"
#include <sstream>
#include <iostream>
#include <iomanip>

namespace iOS {
namespace AIFeatures {

SignatureAdaptation::SignatureAdaptation()
    : m_initialized(false) {}

SignatureAdaptation::~SignatureAdaptation() {}

bool SignatureAdaptation::Initialize() {
    std::lock_guard<std::mutex> lock(m_mutex);
    if (m_initialized) return true;

    if (!m_hybridAI) {
        m_hybridAI = std::make_shared<HybridAISystem>();
        auto& cfg = AIConfig::GetSharedInstance();
        if (!cfg.IsInitialized()) cfg.Initialize();
        m_hybridAI->Initialize("", cfg.GetAPIEndpoint(), cfg.GetAPIKey(),
                               HybridAISystem::OnlineMode::OnlineOnly);
        m_hybridAI->SetModel(cfg.GetOption("model", "openrouter/free"));
    }

    m_initialized = true;
    std::cout << "SignatureAdaptation: online AI ready" << std::endl;
    return true;
}

void SignatureAdaptation::SetHybridAI(std::shared_ptr<HybridAISystem> ai) {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_hybridAI = ai;
}

void SignatureAdaptation::SetResponseCallback(ResponseCallback callback) {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_callback = callback;
}

std::string SignatureAdaptation::BytesToHex(const std::vector<uint8_t>& bytes) const {
    std::ostringstream ss;
    for (size_t i = 0; i < bytes.size() && i < 64; ++i) {
        ss << std::hex << std::setw(2) << std::setfill('0')
           << static_cast<int>(bytes[i]);
    }
    if (bytes.size() > 64) ss << "...";
    return ss.str();
}

void SignatureAdaptation::RequestStrategyFromAI(const std::string& reason) {
    std::shared_ptr<HybridAISystem> ai;
    ResponseCallback cb;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        ai = m_hybridAI;
        cb = m_callback;
    }

    if (!ai || !ai->IsInitialized()) {
        ProtectionStrategy s;
        s.m_name = "Unavailable";
        s.m_description = "Online AI not initialized. Set api_key / api_endpoint.";
        s.m_effectiveness = 0.0f;
        if (cb) cb(s);
        return;
    }

    std::ostringstream prompt;
    prompt << "You are a defensive security assistant for an iOS scripting environment.\n"
           << "Given this detection/adaptation context, suggest a high-level protective strategy.\n"
           << "Do NOT provide instructions to attack other players or bypass game fairness systems maliciously.\n"
           << "Context:\n" << reason << "\n\n"
           << "Respond as plain text with:\n"
           << "NAME: short strategy name\n"
           << "DESCRIPTION: what to do at a high level\n"
           << "CODE: optional short Lua utility snippet for logging/isolation only (or NONE)\n";

    HybridAISystem::AIRequest req(prompt.str(), "", "general");
    ai->ProcessRequest(req, [this, cb](const HybridAISystem::AIResponse& response) {
        ProtectionStrategy strategy;
        strategy.m_lastUpdated = std::chrono::system_clock::now();
        strategy.m_evolutionGeneration = 1;

        if (!response.m_success) {
            strategy.m_name = "Error";
            strategy.m_description = response.m_errorMessage;
            strategy.m_effectiveness = 0.0f;
        } else {
            const std::string& c = response.m_content;
            auto extract = [&c](const char* label) -> std::string {
                size_t p = c.find(label);
                if (p == std::string::npos) return "";
                p += std::char_traits<char>::length(label);
                size_t end = c.find('\n', p);
                if (end == std::string::npos) end = c.size();
                std::string v = c.substr(p, end - p);
                while (!v.empty() && (v.front() == ' ' || v.front() == '\t')) v.erase(v.begin());
                return v;
            };

            strategy.m_name = extract("NAME:");
            strategy.m_description = extract("DESCRIPTION:");
            strategy.m_strategyCode = extract("CODE:");
            if (strategy.m_name.empty()) strategy.m_name = "Adaptive Response";
            if (strategy.m_description.empty()) strategy.m_description = c.substr(0, 500);
            if (strategy.m_strategyCode == "NONE") strategy.m_strategyCode.clear();
            if (strategy.m_strategyCode.empty() && !response.m_scriptCode.empty()) {
                strategy.m_strategyCode = response.m_scriptCode;
            }
            strategy.m_effectiveness = 0.6f;
        }

        {
            std::lock_guard<std::mutex> lock(m_mutex);
            m_lastStrategy = strategy;
        }
        if (cb) cb(strategy);
    });
}

bool SignatureAdaptation::AdaptSignature(const std::string& signature, bool wasDetected) {
    if (!m_initialized) Initialize();

    std::ostringstream reason;
    reason << "Signature adapt request. wasDetected=" << (wasDetected ? "true" : "false")
           << " signature_preview=" << signature.substr(0, 128);

    {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (wasDetected) {
            m_adaptedCache[signature] = signature + "_adapted";
        }
    }

    RequestStrategyFromAI(reason.str());
    return true;
}

std::string SignatureAdaptation::GetAdaptedSignature(const std::string& originalSignature) {
    std::lock_guard<std::mutex> lock(m_mutex);
    auto it = m_adaptedCache.find(originalSignature);
    if (it != m_adaptedCache.end()) return it->second;
    return originalSignature;
}

void SignatureAdaptation::ForceAdaptation() {
    if (!m_initialized) Initialize();
    RequestStrategyFromAI("Force adaptation requested by client.");
}

void SignatureAdaptation::ReportDetection(const DetectionEvent& event) {
    if (!m_initialized) Initialize();

    {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_recentEvents.push_back(event);
        if (m_recentEvents.size() > 20) {
            m_recentEvents.erase(m_recentEvents.begin());
        }
    }

    std::ostringstream reason;
    reason << "Detection reported.\n"
           << "type=" << event.m_detectionType << "\n"
           << "context=" << event.m_context << "\n"
           << "signature_hex=" << BytesToHex(event.m_signature);

    RequestStrategyFromAI(reason.str());
}

SignatureAdaptation::ProtectionStrategy SignatureAdaptation::GetLastStrategy() const {
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_lastStrategy;
}

} // namespace AIFeatures
} // namespace iOS
