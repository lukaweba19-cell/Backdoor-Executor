#include "objc_isolation.h"

#pragma once

#include <string>
#include <vector>
#include <unordered_map>
#include <memory>
#include <functional>
#include <chrono>
#include <mutex>

namespace iOS {
namespace AIFeatures {

    /**
     * @class ScriptAssistant
     * @brief AI assistant for Lua scripting and game analysis
     * 
     * This class implements an AI assistant that can help users with Lua scripting,
     * game analysis, and optimization.
     */
    class ScriptAssistant {
    public:
        // Message type enum
        enum class MessageType {
            System,     // System message
            User,       // User message
            Assistant   // Assistant message
        };
        
        // Message structure for conversation history
        struct Message {
            MessageType m_type;       // Message type
            std::string m_content;    // Message content
            std::chrono::system_clock::time_point m_timestamp; // Message timestamp
            
            Message(MessageType type, const std::string& content)
                : m_type(type), m_content(content), m_timestamp(std::chrono::system_clock::now()) {}
        };
        
        // GameObject structure for game analysis
        struct GameObject {
            std::string m_name;       // Object name
            std::string m_className;  // Object class name
            std::unordered_map<std::string, std::string> m_properties; // Object properties
            std::vector<std::shared_ptr<GameObject>> m_children; // Child objects
            
            GameObject(const std::string& name, const std::string& className)
                : m_name(name), m_className(className) {}
        };
        
        // Game context structure
        struct GameContext {
            std::shared_ptr<GameObject> m_rootObject; // Root game object
            std::unordered_map<std::string, std::string> m_environment; // Environment variables
            std::vector<std::string> m_availableAPIs; // Available APIs
            
            GameContext() : m_rootObject(std::make_shared<GameObject>("Game", "DataModel")) {}
        };
        
        // Script template structure
        struct ScriptTemplate {
            std::string m_name;        // Template name
            std::string m_description; // Template description
            std::string m_code;        // Template code
            
            ScriptTemplate() {}
            
            ScriptTemplate(const std::string& name, const std::string& description,
                          const std::string& code)
                : m_name(name), m_description(description), m_code(code) {}
        };
        
        // Callback for generated scripts
        typedef std::function<void(const std::string&, bool)> ResponseCallback;
        
        // Callback for script execution
        typedef std::function<void(bool, const std::string&)> ScriptExecutionCallback;
        
        // Constructor & destructor
        ScriptAssistant();
        ~ScriptAssistant();
        
        // Initialization
        bool Initialize();
        void SetResponseCallback(ResponseCallback callback);
        void SetExecutionCallback(ScriptExecutionCallback callback);
        
        // User interaction methods
        void ProcessUserInput(const std::string& input);
        void ReleaseUnusedResources();
        uint64_t GetMemoryUsage() const;
        void GenerateScript(const std::string& description);
        void AnalyzeGame(const GameContext& context);
        void OptimizeScript(const std::string& script);
        void ExecuteScript(const std::string& script);
        
        // Configuration methods
        void LoadTemplates(const std::string& templatesPath);
        void SaveTemplates(const std::string& templatesPath);
        void AddTemplate(const ScriptTemplate& tmpl);
        void RemoveTemplate(const std::string& templateName);
        
        // Helper methods
        std::vector<std::string> GetSuggestions(const std::string& partialInput);
        std::vector<ScriptTemplate> GetTemplates() const;
        GameContext GetCurrentContext() const;
        
        // Memory management
        void ClearConversationHistory();
        void TrimConversationHistory();
        
        // Static helpers
        static std::vector<std::string> GetExampleQueries();
        static std::vector<std::string> GetExampleScriptDescriptions();
        
    private:
        // Private implementation details
        size_t m_maxHistorySize;               // Maximum history size
        std::vector<Message> m_conversationHistory; // Conversation history
        GameContext m_currentContext;         // Current game context
        std::vector<ScriptTemplate> m_scriptTemplates; // Script templates
        std::unordered_map<std::string, std::string> m_userPreferences; // User preferences
        void* m_languageModel;                // Opaque pointer to language model
        void* m_gameAnalyzer;                 // Opaque pointer to game analyzer
        void* m_scriptGenerator;              // Opaque pointer to script generator
        void* m_executionInterface;           // Opaque pointer to execution interface
        ResponseCallback m_responseCallback;  // Callback for responses
        ScriptExecutionCallback m_executionCallback; // Callback for script execution
        std::mutex m_mutex;                   // Mutex for thread safety
        
        // Private helper methods
        void AddSystemMessage(const std::string& message);
        void AddUserMessage(const std::string& message);
        void AddAssistantMessage(const std::string& message);
        std::string GenerateResponse(const std::string& input);
        void LoadDefaultTemplates();
    };
    
} // namespace AIFeatures
} // namespace iOS
