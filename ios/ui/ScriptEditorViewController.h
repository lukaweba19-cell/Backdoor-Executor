#pragma once

// Forward declarations of Objective-C classes (must be at global scope)
@class UIViewController;
@class UITextView;
@class UIButton;
@class UIColor;

#include "../../ios_compat.h"
#include <string>
#include <vector>
#include <functional>
#include <memory>
#include <unordered_map>

// Forward declaration for AI features
namespace iOS {
namespace AIFeatures {
    class ScriptAssistant;
}
}

namespace iOS {
namespace UI {

/**
 * @class ScriptEditorViewController
 * @brief View controller for script editing and execution
 * 
 * This class manages the script editor UI, including syntax highlighting,
 * code completion, and script execution.
 */
class ScriptEditorViewController {
public:
    // Script execution callback
    using ExecutionCallback = std::function<void(const std::string&, bool)>;
    
    // Script save callback
    using SaveCallback = std::function<void(const std::string&, const std::string&)>;
    
    // Code completion callback
    using CompletionCallback = std::function<void(const std::string&)>;
    
    // Syntax highlighting types
    enum class SyntaxType {
        Keyword,        // Lua keywords
        Function,       // Function names
        String,         // String literals
        Number,         // Number literals
        Comment,        // Comments
        Operator,       // Operators
        Identifier,     // Identifiers
        Library,        // Lua library functions
        RobloxAPI,      // Roblox API functions
        Error           // Syntax errors
    };
    
    // Script execution modes
    enum class ExecutionMode {
        Normal,         // Normal execution
        Protected,      // Protected mode
        Sandboxed,      // Sandboxed environment
        Isolated        // Fully isolated environment
    };
    
    // Theme types
    enum class EditorTheme {
        Light,          // Light theme
        Dark,           // Dark theme
        Solarized,      // Solarized theme
        Monokai,        // Monokai theme
        Custom          // Custom theme
    };
    
    // Auto-completion mode
    enum class CompletionMode {
        Manual,         // Manual activation only
        Basic,          // Basic auto-completion
        Intelligent     // Intelligent context-aware completion
    };
    
private:
    // Private implementation
    UIViewController* m_viewController;       // The UIViewController
    UITextView* m_textView;                   // The text view for editing
    UITextView* m_outputView;                 // Output/console view
    
    std::string m_scriptContent;              // Current script content
    std::string m_scriptName;                 // Script name
    std::string m_filePath;                   // File path if saved
    bool m_modified;                          // Whether content is modified
    
    EditorTheme m_theme;                      // Current theme
    CompletionMode m_completionMode;          // Completion mode
    ExecutionMode m_executionMode;            // Execution mode
    
    ExecutionCallback m_executionCallback;    // Callback for execution
    SaveCallback m_saveCallback;              // Callback for save
    CompletionCallback m_completionCallback;  // Callback for completion
    
    // AI integration
    std::shared_ptr<AIFeatures::ScriptAssistant> m_scriptAssistant; // Script assistant
    
    // Theme colors
    void* m_backgroundColor;        // Background color
    void* m_textColor;              // Text color
    void* m_keywordColor;           // Keyword color
    void* m_functionColor;          // Function color
    void* m_stringColor;            // String color
    void* m_numberColor;            // Number color
    void* m_commentColor;           // Comment color
    void* m_operatorColor;          // Operator color
    void* m_identifierColor;        // Identifier color
    void* m_libraryColor;           // Library function color
    void* m_robloxAPIColor;         // Roblox API color
    void* m_errorColor;             // Error color
    
    // Saved scripts
    std::unordered_map<std::string, std::string> m_savedScripts;
    
    // Private helper methods
    void InitializeUI();
    void ApplyTheme();
    void UpdateSyntaxHighlighting();
    void HandleTextChange();
    void ShowCompletionSuggestions();
    bool SaveScriptToFile(const std::string& path);
    bool LoadScriptFromFile(const std::string& path);
    void AppendToOutput(const std::string& text, bool isError = false);
    void ClearOutput();
    
public:
    /**
     * @brief Constructor
     */
    ScriptEditorViewController();
    
    /**
     * @brief Destructor
     */
    ~ScriptEditorViewController();
    
    /**
     * @brief Get the UIViewController
     * @return UIViewController pointer
     */
    UIViewController* GetViewController() const;
    
    /**
     * @brief Set script content
     * @param content Script content
     */
    void SetScriptContent(const std::string& content);
    
    /**
     * @brief Get script content
     * @return Script content
     */
    std::string GetScriptContent() const;
    
    /**
     * @brief Set script name
     * @param name Script name
     */
    void SetScriptName(const std::string& name);
    
    /**
     * @brief Get script name
     * @return Script name
     */
    std::string GetScriptName() const;
    
    /**
     * @brief Execute script
     * @return True if successful
     */
    bool ExecuteScript();
    
    /**
     * @brief Save script
     * @param name Script name
     * @return True if successful
     */
    bool SaveScript(const std::string& name);
    
    /**
     * @brief Load script
     * @param name Script name
     * @return True if successful
     */
    bool LoadScript(const std::string& name);
    
    /**
     * @brief Set theme
     * @param theme Editor theme
     */
    void SetTheme(EditorTheme theme);
    
    /**
     * @brief Get theme
     * @return Editor theme
     */
    EditorTheme GetTheme() const;
    
    /**
     * @brief Set completion mode
     * @param mode Completion mode
     */
    void SetCompletionMode(CompletionMode mode);
    
    /**
     * @brief Get completion mode
     * @return Completion mode
     */
    CompletionMode GetCompletionMode() const;
    
    /**
     * @brief Set execution mode
     * @param mode Execution mode
     */
    void SetExecutionMode(ExecutionMode mode);
    
    /**
     * @brief Get execution mode
     * @return Execution mode
     */
    ExecutionMode GetExecutionMode() const;
    
    /**
     * @brief Set execution callback
     * @param callback Execution callback
     */
    void SetExecutionCallback(ExecutionCallback callback);
    
    /**
     * @brief Set save callback
     * @param callback Save callback
     */
    void SetSaveCallback(SaveCallback callback);
    
    /**
     * @brief Set completion callback
     * @param callback Completion callback
     */
    void SetCompletionCallback(CompletionCallback callback);
    
    /**
     * @brief Set script assistant
     * @param assistant Script assistant
     */
    void SetScriptAssistant(std::shared_ptr<AIFeatures::ScriptAssistant> assistant);
    
    /**
     * @brief Get saved scripts
     * @return Map of script names to content
     */
    std::unordered_map<std::string, std::string> GetSavedScripts() const;
    
    /**
     * @brief Check if script is modified
     * @return True if modified
     */
    bool IsModified() const;
    
    /**
     * @brief Clear script
     */
    void ClearScript();
};

} // namespace UI
} // namespace iOS
