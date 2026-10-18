#include "ios_compat.h"
#include "ScriptAssistant.h"
#include "HybridAISystem.h"
#include "AIConfig.h"
#include <iostream>
#include <algorithm>
#include <mutex>

namespace iOS {
namespace AIFeatures {

ScriptAssistant::ScriptAssistant()
    : m_maxHistorySize(40),
      m_languageModel(nullptr),
      m_gameAnalyzer(nullptr),
      m_scriptGenerator(nullptr),
      m_executionInterface(nullptr),
      m_responseCallback(nullptr),
      m_executionCallback(nullptr) {}

ScriptAssistant::~ScriptAssistant() {
    // Online-only — no local model pointers to free
    m_languageModel = nullptr;
    m_scriptGenerator = nullptr;
}

bool ScriptAssistant::Initialize() {
    std::lock_guard<std::mutex> lock(m_mutex);
    LoadDefaultTemplates();
    AddSystemMessage(
        "You are a Lua scripting assistant. Help with utility scripts, debugging, and Lua APIs. "
        "Do not generate aimbot, ESP, or speed-hack scripts.");
    std::cout << "ScriptAssistant: initialized (online AI via HybridAISystem)" << std::endl;
    return true;
}

void ScriptAssistant::SetResponseCallback(ResponseCallback callback) {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_responseCallback = callback;
}

void ScriptAssistant::SetExecutionCallback(ScriptExecutionCallback callback) {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_executionCallback = callback;
}

void ScriptAssistant::AddSystemMessage(const std::string& message) {
    m_conversationHistory.emplace_back(MessageType::System, message);
    TrimConversationHistory();
}

void ScriptAssistant::AddUserMessage(const std::string& message) {
    m_conversationHistory.emplace_back(MessageType::User, message);
    TrimConversationHistory();
}

void ScriptAssistant::AddAssistantMessage(const std::string& message) {
    m_conversationHistory.emplace_back(MessageType::Assistant, message);
    TrimConversationHistory();
}

void ScriptAssistant::TrimConversationHistory() {
    while (m_conversationHistory.size() > m_maxHistorySize) {
        // Keep first system message if present
        size_t start = 0;
        if (!m_conversationHistory.empty() &&
            m_conversationHistory.front().m_type == MessageType::System) {
            start = 1;
        }
        if (m_conversationHistory.size() > start) {
            m_conversationHistory.erase(m_conversationHistory.begin() + static_cast<long>(start));
        } else {
            break;
        }
    }
}

void ScriptAssistant::ClearConversationHistory() {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_conversationHistory.clear();
}

void ScriptAssistant::ReleaseUnusedResources() {
    // Online-only — nothing local to release
}

uint64_t ScriptAssistant::GetMemoryUsage() const {
    return 0;
}

static std::shared_ptr<HybridAISystem> GetOrCreateHybrid() {
    static std::shared_ptr<HybridAISystem> hybrid;
    static std::once_flag once;
    std::call_once(once, []() {
        hybrid = std::make_shared<HybridAISystem>();
        auto& cfg = AIConfig::GetSharedInstance();
        if (!cfg.IsInitialized()) cfg.Initialize();
        hybrid->Initialize("", cfg.GetAPIEndpoint(), cfg.GetAPIKey(),
                           HybridAISystem::OnlineMode::OnlineOnly);
        std::string model = cfg.GetOption("model", "openrouter/free");
        hybrid->SetModel(model);
    });
    return hybrid;
}

std::string ScriptAssistant::GenerateResponse(const std::string& input) {
    auto hybrid = GetOrCreateHybrid();
    if (!hybrid || !hybrid->IsInitialized()) {
        return "AI not initialized. Set api_key / api_endpoint in AIConfig.";
    }

    HybridAISystem::AIRequest req(input, "", "general");
    // Attach short history as context
    std::string ctx;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        for (const auto& msg : m_conversationHistory) {
            if (msg.m_type == MessageType::User)
                ctx += "User: " + msg.m_content + "\n";
            else if (msg.m_type == MessageType::Assistant)
                ctx += "Assistant: " + msg.m_content + "\n";
        }
    }
    req.m_context = ctx;

    auto response = hybrid->ProcessRequestSync(req);
    if (!response.m_success) {
        return "Error: " + response.m_errorMessage;
    }
    return response.m_content;
}

void ScriptAssistant::ProcessUserInput(const std::string& input) {
    AddUserMessage(input);
    std::string response = GenerateResponse(input);
    AddAssistantMessage(response);
    if (m_responseCallback) {
        m_responseCallback(response, true);
    }
}

void ScriptAssistant::GenerateScript(const std::string& description) {
    auto hybrid = GetOrCreateHybrid();
    if (!hybrid || !hybrid->IsInitialized()) {
        if (m_responseCallback)
            m_responseCallback("AI not initialized. Set api_key / api_endpoint.", false);
        return;
    }

    hybrid->GenerateScript(description, "", [this](const HybridAISystem::AIResponse& r) {
        std::string out;
        if (!r.m_success) {
            out = "Error: " + r.m_errorMessage;
            if (m_responseCallback) m_responseCallback(out, false);
            return;
        }
        out = r.m_scriptCode.empty() ? r.m_content : r.m_scriptCode;
        AddAssistantMessage(out);
        if (m_responseCallback) m_responseCallback(out, true);
    });
}

void ScriptAssistant::AnalyzeGame(const GameContext& context) {
    m_currentContext = context;
    ProcessUserInput("Analyze the current game context and suggest useful utility scripts.");
}

void ScriptAssistant::OptimizeScript(const std::string& script) {
    auto hybrid = GetOrCreateHybrid();
    if (!hybrid) {
        if (m_responseCallback) m_responseCallback("AI not available", false);
        return;
    }
    HybridAISystem::AIRequest req("Optimize this Lua script for clarity and performance",
                                  script, "debug");
    hybrid->ProcessRequest(req, [this](const HybridAISystem::AIResponse& r) {
        std::string out = r.m_success ? r.m_content : ("Error: " + r.m_errorMessage);
        if (m_responseCallback) m_responseCallback(out, r.m_success);
    });
}

void ScriptAssistant::ExecuteScript(const std::string& script) {
    if (m_executionCallback) {
        m_executionCallback(true, script);
    } else if (m_responseCallback) {
        m_responseCallback("No execution callback set. Script ready:\n" + script, true);
    }
}

void ScriptAssistant::LoadTemplates(const std::string& /*templatesPath*/) {
    LoadDefaultTemplates();
}

void ScriptAssistant::SaveTemplates(const std::string& /*templatesPath*/) {
    // No-op — templates are in-memory only
}

void ScriptAssistant::AddTemplate(const ScriptTemplate& tmpl) {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_scriptTemplates.push_back(tmpl);
}

void ScriptAssistant::RemoveTemplate(const std::string& templateName) {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_scriptTemplates.erase(
        std::remove_if(m_scriptTemplates.begin(), m_scriptTemplates.end(),
                       [&](const ScriptTemplate& t) { return t.m_name == templateName; }),
        m_scriptTemplates.end());
}

std::vector<std::string> ScriptAssistant::GetSuggestions(const std::string& partialInput) {
    std::vector<std::string> suggestions;
    std::string lower = partialInput;
    std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);
    if (lower.find("generat") != std::string::npos) {
        suggestions.push_back("generate a utility UI script");
        suggestions.push_back("generate a remote event helper");
    } else if (lower.find("debug") != std::string::npos) {
        suggestions.push_back("debug this script");
    } else {
        suggestions.push_back("explain this Lua code");
        suggestions.push_back("generate a simple UI framework");
        suggestions.push_back("help with RemoteEvents");
    }
    return suggestions;
}

std::vector<ScriptAssistant::ScriptTemplate> ScriptAssistant::GetTemplates() const {
    return m_scriptTemplates;
}

ScriptAssistant::GameContext ScriptAssistant::GetCurrentContext() const {
    return m_currentContext;
}

std::vector<std::string> ScriptAssistant::GetExampleQueries() {
    return {
        "How do I use RemoteEvents in Lua?",
        "Explain pairs vs ipairs",
        "Generate a simple ScreenGui framework",
        "Debug this script for me"
    };
}

std::vector<std::string> ScriptAssistant::GetExampleScriptDescriptions() {
    return {
        "Simple UI framework for scripts",
        "Remote event helper module",
        "Basic movement state handler"
    };
}

void ScriptAssistant::LoadDefaultTemplates() {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_scriptTemplates.clear();

    ScriptTemplate uiTemplate;
    uiTemplate.m_name = "Simple UI Framework";
    uiTemplate.m_description = "Framework for creating a simple UI for scripts";
    uiTemplate.m_code = R"(
-- Simple UI Framework
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local UI = { Title = "Script Hub", Width = 300, Height = 350 }

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ScriptHubUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, UI.Width, 0, UI.Height)
mainFrame.Position = UDim2.new(0.5, -UI.Width/2, 0.5, -UI.Height/2)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

return UI
)";
    m_scriptTemplates.push_back(uiTemplate);

    ScriptTemplate remoteTemplate;
    remoteTemplate.m_name = "Remote Event Helper";
    remoteTemplate.m_description = "Simple client/server remote event helper module";
    remoteTemplate.m_code = R"(
-- Remote Event Helper
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local module = {}
local remoteEvent = ReplicatedStorage:FindFirstChild("RemoteEvent") or Instance.new("RemoteEvent")
remoteEvent.Name = "RemoteEvent"
remoteEvent.Parent = ReplicatedStorage

function module.fireServer(...)
    remoteEvent:FireServer(...)
end

function module.onClientEvent(callback)
    remoteEvent.OnClientEvent:Connect(callback)
end

return module
)";
    m_scriptTemplates.push_back(remoteTemplate);
}

} // namespace AIFeatures
} // namespace iOS
