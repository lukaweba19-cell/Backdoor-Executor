#include "ios_compat.h"
#include "HybridAISystem.h"
#include "OnlineService.h"
#include <sstream>
#include <iostream>
#include <algorithm>

namespace iOS {
namespace AIFeatures {

HybridAISystem::HybridAISystem()
    : m_initialized(false),
      m_networkConnected(false),
      m_model("openrouter/free"),
      m_onlineMode(OnlineMode::OnlineOnly) {}

HybridAISystem::~HybridAISystem() {}

bool HybridAISystem::Initialize(const std::string& /*modelPath*/,
                                const std::string& apiEndpoint,
                                const std::string& apiKey,
                                OnlineMode mode) {
    std::lock_guard<std::mutex> lock(m_mutex);

    m_apiEndpoint = apiEndpoint;
    m_apiKey = apiKey;
    m_onlineMode = mode;

    // Default to OpenAI-compatible base if empty
    if (m_apiEndpoint.empty()) {
        m_apiEndpoint = "https://openrouter.ai/api/v1";
    }

    m_onlineService = std::make_shared<OnlineService>();
    if (!m_onlineService->Initialize(m_apiEndpoint, m_apiKey)) {
        std::cerr << "HybridAISystem: Failed to initialize OnlineService" << std::endl;
        m_initialized = false;
        return false;
    }

    m_networkConnected = CheckNetworkConnectivity();
    m_initialized = true;

    std::cout << "HybridAISystem: Online AI ready (endpoint=" << m_apiEndpoint
              << ", model=" << m_model << ", network="
              << (m_networkConnected ? "yes" : "no") << ")" << std::endl;
    return true;
}

void HybridAISystem::SetAPIEndpoint(const std::string& endpoint) {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_apiEndpoint = endpoint.empty() ? "https://openrouter.ai/api/v1" : endpoint;
    if (m_onlineService) {
        m_onlineService->SetBaseUrl(m_apiEndpoint);
    }
}

void HybridAISystem::SetAPIKey(const std::string& apiKey) {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_apiKey = apiKey;
    if (m_onlineService) {
        m_onlineService->SetAPIKey(apiKey);
    }
}

bool HybridAISystem::CheckNetworkConnectivity() {
    // Lightweight reachability: OnlineService will surface real failures.
    // Treat as connected unless we have no endpoint/key.
    return !m_apiEndpoint.empty();
}

std::string HybridAISystem::EscapeJSON(const std::string& s) const {
    std::string out;
    out.reserve(s.size() + 8);
    for (char c : s) {
        switch (c) {
            case '\"': out += "\\\""; break;
            case '\\': out += "\\\\"; break;
            case '\b': out += "\\b"; break;
            case '\f': out += "\\f"; break;
            case '\n': out += "\\n"; break;
            case '\r': out += "\\r"; break;
            case '\t': out += "\\t"; break;
            default:
                if (static_cast<unsigned char>(c) < 0x20) {
                    char buf[8];
                    snprintf(buf, sizeof(buf), "\\u%04x", c);
                    out += buf;
                } else {
                    out += c;
                }
        }
    }
    return out;
}

std::string HybridAISystem::BuildSystemPrompt(const AIRequest& request) const {
    std::string prompt =
        "You are a helpful Lua scripting assistant for a Roblox executor on iOS. "
        "Help with Lua syntax, APIs, debugging, and utility/UI scripts only. "
        "Do NOT generate aimbot, ESP, speed hacks, or other cheating scripts. "
        "When generating code, put the full Lua script inside a ```lua ... ``` block.";

    if (request.m_requestType == "script_generation") {
        prompt += " The user wants a script generated from their description.";
    } else if (request.m_requestType == "debug") {
        prompt += " The user wants help debugging a script. Explain errors and suggest fixes.";
    }
    return prompt;
}

std::string HybridAISystem::BuildChatCompletionsBody(const AIRequest& request) const {
    std::string systemPrompt = BuildSystemPrompt(request);

    std::string userContent = request.m_query;
    if (!request.m_context.empty()) {
        userContent += "\n\nContext:\n" + request.m_context;
    }
    if (!request.m_gameInfo.empty()) {
        userContent += "\n\nGame info:\n" + request.m_gameInfo;
    }

    // OpenAI-compatible chat completions body
    std::ostringstream ss;
    ss << "{"
       << "\"model\":\"" << EscapeJSON(m_model) << "\","
       << "\"messages\":["
       << "{\"role\":\"system\",\"content\":\"" << EscapeJSON(systemPrompt) << "\"},"
       << "{\"role\":\"user\",\"content\":\"" << EscapeJSON(userContent) << "\"}"
       << "],"
       << "\"temperature\":0.4,"
       << "\"max_tokens\":2048"
       << "}";
    return ss.str();
}

std::string HybridAISystem::ExtractContentFromOpenAIResponse(const std::string& body) const {
    // Prefer choices[0].message.content
    const std::string key = "\"content\":\"";
    // Find the last content field that looks like message content (after "message")
    size_t msgPos = body.find("\"message\"");
    size_t searchFrom = (msgPos != std::string::npos) ? msgPos : 0;
    size_t pos = body.find(key, searchFrom);
    if (pos == std::string::npos) {
        pos = body.find(key); // fallback first content
    }
    if (pos == std::string::npos) {
        return "";
    }
    pos += key.size();

    std::string result;
    result.reserve(256);
    for (size_t i = pos; i < body.size(); ++i) {
        char c = body[i];
        if (c == '\\' && i + 1 < body.size()) {
            char n = body[i + 1];
            if (n == 'n') { result += '\n'; ++i; }
            else if (n == 't') { result += '\t'; ++i; }
            else if (n == 'r') { result += '\r'; ++i; }
            else if (n == '"') { result += '"'; ++i; }
            else if (n == '\\') { result += '\\'; ++i; }
            else if (n == 'u' && i + 5 < body.size()) { i += 5; } // skip \uXXXX
            else { result += n; ++i; }
        } else if (c == '"') {
            break;
        } else {
            result += c;
        }
    }
    return result;
}

std::string HybridAISystem::ExtractScriptFromContent(const std::string& content) const {
    // Pull first ```lua ... ``` or ``` ... ``` block
    size_t start = content.find("```lua");
    size_t tagLen = 6;
    if (start == std::string::npos) {
        start = content.find("```");
        tagLen = 3;
    }
    if (start == std::string::npos) return "";

    start = content.find('\n', start);
    if (start == std::string::npos) return "";
    ++start;

    size_t end = content.find("```", start);
    if (end == std::string::npos) return content.substr(start);
    return content.substr(start, end - start);
}

HybridAISystem::AIResponse HybridAISystem::ProcessRequestOnline(const AIRequest& request) {
    AIResponse response;
    response.m_usedOnlineMode = true;

    if (!m_onlineService) {
        response.m_success = false;
        response.m_errorMessage = "OnlineService not initialized";
        return response;
    }
    if (m_apiKey.empty()) {
        response.m_success = false;
        response.m_errorMessage = "API key not set. Configure api_key in AIConfig.";
        return response;
    }

    // Build OpenAI-compatible request to /chat/completions
    OnlineService::Request req;
    req.m_method = "POST";
    req.m_endpoint = "/chat/completions";
    if (!m_apiEndpoint.empty() && m_apiEndpoint.back() == '/') {
        // OnlineService joins base + endpoint
    }
    req.m_body = BuildChatCompletionsBody(request);
    req.m_headers.push_back({"Content-Type", "application/json"});
    // OpenRouter recommended attribution headers (harmless for other OpenAI-compatible APIs)
    req.m_headers.push_back({"HTTP-Referer", "https://github.com/backdoor-executor"});
    req.m_headers.push_back({"X-Title", "Backdoor Executor iOS"});
    req.m_timeoutMs = 60000;

    auto httpResponse = m_onlineService->SendRequestSync(req);

    if (!httpResponse.m_success) {
        response.m_success = false;
        response.m_errorMessage = httpResponse.m_errorMessage.empty()
            ? ("HTTP request failed (status " + std::to_string(httpResponse.m_statusCode) + ")")
            : httpResponse.m_errorMessage;
        return response;
    }

    if (httpResponse.m_statusCode < 200 || httpResponse.m_statusCode >= 300) {
        response.m_success = false;
        response.m_errorMessage = "API error HTTP " + std::to_string(httpResponse.m_statusCode)
            + ": " + httpResponse.m_body.substr(0, 300);
        return response;
    }

    std::string content = ExtractContentFromOpenAIResponse(httpResponse.m_body);
    if (content.empty()) {
        // Fallback: try generic "content" parse via OnlineService helper
        content = m_onlineService->ParseAIResponse(httpResponse);
    }
    if (content.empty()) {
        response.m_success = false;
        response.m_errorMessage = "Could not parse AI response content";
        return response;
    }

    response.m_success = true;
    response.m_content = content;
    response.m_scriptCode = ExtractScriptFromContent(content);

    if (request.m_requestType == "script_generation") {
        response.m_suggestions.push_back("Execute generated script");
        response.m_suggestions.push_back("Refine description");
    } else if (request.m_requestType == "debug") {
        response.m_suggestions.push_back("Apply suggested fix");
        response.m_suggestions.push_back("Explain error further");
    } else {
        response.m_suggestions.push_back("Generate a utility script");
        response.m_suggestions.push_back("Debug a script");
    }

    return response;
}

HybridAISystem::AIResponse HybridAISystem::ProcessRequestSync(const AIRequest& request) {
    AIResponse response;

    if (!m_initialized) {
        response.m_success = false;
        response.m_errorMessage = "AI system not initialized";
        return response;
    }

    m_networkConnected = CheckNetworkConnectivity();
    if (!m_networkConnected || m_apiEndpoint.empty()) {
        response.m_success = false;
        response.m_errorMessage =
            "Network/API unavailable — configure api_endpoint and api_key. Offline AI has been removed.";
        response.m_usedOnlineMode = false;
        return response;
    }

    auto start = std::chrono::high_resolution_clock::now();
    response = ProcessRequestOnline(request);
    auto end = std::chrono::high_resolution_clock::now();
    response.m_processingTime =
        std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();

    {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_requestHistory.push_back(request);
        m_responseHistory.push_back(response);
        if (m_requestHistory.size() > 50) {
            m_requestHistory.erase(m_requestHistory.begin());
            m_responseHistory.erase(m_responseHistory.begin());
        }
    }

    return response;
}

void HybridAISystem::ProcessRequest(const AIRequest& request, ResponseCallback callback) {
    if (!callback) return;
    // Sync call on caller thread; UI should dispatch to background if needed
    AIResponse response = ProcessRequestSync(request);
    callback(response);
}

void HybridAISystem::GenerateScript(const std::string& description,
                                    const std::string& context,
                                    ResponseCallback callback,
                                    bool /*useOnline*/) {
    AIRequest req(description, context, "script_generation");
    ProcessRequest(req, callback);
}

void HybridAISystem::DebugScript(const std::string& script,
                                 ResponseCallback callback,
                                 bool /*useOnline*/) {
    AIRequest req("Debug this script", script, "debug");
    ProcessRequest(req, callback);
}

void HybridAISystem::ProcessQuery(const std::string& query,
                                  ResponseCallback callback,
                                  bool /*useOnline*/) {
    AIRequest req(query, "", "general");
    ProcessRequest(req, callback);
}

} // namespace AIFeatures
} // namespace iOS
