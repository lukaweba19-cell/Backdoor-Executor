#pragma once

#include "objc_isolation.h"
#include <string>
#include <vector>
#include <functional>
#include <memory>
#include <unordered_map>
#include <mutex>
#include <atomic>
#include <chrono>

namespace iOS {
namespace AIFeatures {

class OnlineService; // forward

/**
 * @class HybridAISystem
 * @brief Online-only AI system (OpenAI-compatible chat API)
 *
 * All local models and offline/training paths have been removed.
 * Requires network + api_endpoint + api_key.
 */
class HybridAISystem {
public:
    struct AIRequest {
        std::string m_query;
        std::string m_context;
        std::string m_gameInfo;
        std::string m_requestType; // script_generation | debug | general
        std::vector<std::string> m_history;
        bool m_forceOffline; // ignored (offline removed)

        AIRequest(const std::string& query = "",
                  const std::string& context = "",
                  const std::string& requestType = "general",
                  bool forceOffline = false)
            : m_query(query), m_context(context), m_requestType(requestType),
              m_forceOffline(forceOffline) {}
    };

    struct AIResponse {
        bool m_success;
        std::string m_content;
        std::string m_scriptCode;
        std::vector<std::string> m_suggestions;
        uint64_t m_processingTime;
        std::string m_errorMessage;
        bool m_usedOnlineMode;

        AIResponse()
            : m_success(false), m_processingTime(0), m_usedOnlineMode(true) {}

        AIResponse(bool success, const std::string& content = "",
                   const std::string& scriptCode = "", uint64_t processingTime = 0,
                   const std::string& errorMessage = "")
            : m_success(success), m_content(content), m_scriptCode(scriptCode),
              m_processingTime(processingTime), m_errorMessage(errorMessage),
              m_usedOnlineMode(true) {}
    };

    using ResponseCallback = std::function<void(const AIResponse&)>;

    enum class OnlineMode {
        Auto,
        PreferOnline,
        OnlineOnly
    };

    HybridAISystem();
    ~HybridAISystem();

    bool Initialize(const std::string& modelPath,
                    const std::string& apiEndpoint,
                    const std::string& apiKey,
                    OnlineMode mode = OnlineMode::OnlineOnly);

    bool IsInitialized() const { return m_initialized; }

    void ProcessRequest(const AIRequest& request, ResponseCallback callback);
    AIResponse ProcessRequestSync(const AIRequest& request);

    void GenerateScript(const std::string& description,
                        const std::string& context,
                        ResponseCallback callback,
                        bool useOnline = true);
    void DebugScript(const std::string& script,
                     ResponseCallback callback,
                     bool useOnline = true);
    void ProcessQuery(const std::string& query,
                      ResponseCallback callback,
                      bool useOnline = true);

    void SetAPIEndpoint(const std::string& endpoint);
    void SetAPIKey(const std::string& apiKey);
    void SetOnlineMode(OnlineMode mode) { m_onlineMode = mode; }
    void SetModel(const std::string& model) { m_model = model; }

    std::string GetAPIEndpoint() const { return m_apiEndpoint; }
    std::string GetModel() const { return m_model; }
    bool IsNetworkConnected() const { return m_networkConnected; }

private:
    AIResponse ProcessRequestOnline(const AIRequest& request);
    bool CheckNetworkConnectivity();
    std::string BuildSystemPrompt(const AIRequest& request) const;
    std::string BuildChatCompletionsBody(const AIRequest& request) const;
    std::string ExtractContentFromOpenAIResponse(const std::string& body) const;
    std::string ExtractScriptFromContent(const std::string& content) const;
    std::string EscapeJSON(const std::string& s) const;

    bool m_initialized;
    bool m_networkConnected;
    std::string m_apiEndpoint;
    std::string m_apiKey;
    std::string m_model; // e.g. openrouter/free (OpenRouter)
    OnlineMode m_onlineMode;

    std::shared_ptr<OnlineService> m_onlineService;

    std::vector<AIRequest> m_requestHistory;
    std::vector<AIResponse> m_responseHistory;
    mutable std::mutex m_mutex;
};

} // namespace AIFeatures
} // namespace iOS
