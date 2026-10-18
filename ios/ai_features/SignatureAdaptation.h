#pragma once
#include "objc_isolation.h"
#include <string>
#include <vector>
#include <cstdint>
#include <functional>
#include <chrono>
#include <memory>
#include <mutex>
#include <unordered_map>

namespace iOS {
namespace AIFeatures {

class HybridAISystem; // forward

/**
 * Online signature / detection adaptation via HybridAISystem.
 * Suggests defensive strategy notes — no local ML training.
 */
class SignatureAdaptation {
public:
    struct DetectionEvent {
        std::string m_detectionType;
        std::vector<uint8_t> m_signature;
        uint64_t m_timestamp;
        std::string m_context;

        DetectionEvent() : m_timestamp(0) {}
        DetectionEvent(const std::string& type,
                       const std::vector<uint8_t>& signature,
                       const std::string& context = "")
            : m_detectionType(type),
              m_signature(signature),
              m_timestamp(std::chrono::system_clock::now().time_since_epoch().count()),
              m_context(context) {}
    };

    struct ProtectionStrategy {
        std::string m_name;
        std::string m_description;
        std::string m_strategyCode;
        float m_effectiveness;
        uint32_t m_evolutionGeneration;
        std::chrono::system_clock::time_point m_lastUpdated;

        ProtectionStrategy()
            : m_effectiveness(0.0f),
              m_evolutionGeneration(0),
              m_lastUpdated(std::chrono::system_clock::now()) {}
    };

    using ResponseCallback = std::function<void(const ProtectionStrategy&)>;

    SignatureAdaptation();
    ~SignatureAdaptation();

    bool Initialize();
    void SetHybridAI(std::shared_ptr<HybridAISystem> ai);

    void ReleaseUnusedResources() {}
    uint64_t GetMemoryUsage() const { return 0; }

    void SetResponseCallback(ResponseCallback callback);

    bool AdaptSignature(const std::string& signature, bool wasDetected);
    std::string GetAdaptedSignature(const std::string& originalSignature);
    void ForceAdaptation();
    void ReportDetection(const DetectionEvent& event);

    ProtectionStrategy GetLastStrategy() const;

private:
    void RequestStrategyFromAI(const std::string& reason);
    std::string BytesToHex(const std::vector<uint8_t>& bytes) const;

    std::shared_ptr<HybridAISystem> m_hybridAI;
    ResponseCallback m_callback;
    ProtectionStrategy m_lastStrategy;
    std::unordered_map<std::string, std::string> m_adaptedCache;
    std::vector<DetectionEvent> m_recentEvents;
    bool m_initialized;
    mutable std::mutex m_mutex;
};

} // namespace AIFeatures
} // namespace iOS
