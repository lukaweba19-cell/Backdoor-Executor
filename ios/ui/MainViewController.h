#pragma once

#include "../../objc_isolation.h"
#include <string>
#include <memory>
#include <functional>
#include <vector>

namespace iOS {
namespace UI {

// Forward declaration for implementation class
class MainViewControllerImpl;

/**
 * @class MainViewController
 * @brief Main view controller for the executor UI
 * 
 * This class provides the main user interface for the Roblox executor.
 * It manages tabs, floating buttons, and other UI elements.
 */
class MainViewController {
public:
    // Tab enumeration
    enum class Tab {
        Editor,     // Script editor tab
        Scripts,    // Saved scripts tab
        Console,    // Output console tab
        Settings    // Settings tab
    };
    
    // Script information structure
    struct ScriptInfo {
        std::string m_name;       // Script name
        std::string m_content;    // Script content
        uint64_t m_timestamp;     // Script timestamp
    };
    
    // Execution result structure
    struct ExecutionResult {
        bool m_success;           // Whether execution succeeded
        std::string m_output;     // Output from execution
        uint64_t m_executionTime; // Execution time in milliseconds
    };
    
    // Callback types
    using ExecutionCallback = std::function<void(const ExecutionResult&)>;
    using SaveScriptCallback = std::function<bool(const std::string&)>;
    using LoadScriptsCallback = std::function<std::vector<ScriptInfo>()>;
    using AIQueryCallback = std::function<void(const std::string&)>;
    using AIResponseCallback = std::function<void(const std::string&)>;
    using TabChangedCallback = std::function<void(Tab)>;
    using VisibilityChangedCallback = std::function<void(bool)>;

private:
    MainViewControllerImpl* m_impl;

public:
    /**
     * @brief Constructor
     */
    MainViewController();
    
    /**
     * @brief Destructor
     */
    ~MainViewController();
    
    /**
     * @brief Execute a script
     * @param script Script to execute
     * @return True if execution succeeded
     */
    bool ExecuteScript(const std::string& script);
    
    /**
     * @brief Display AI response in UI
     * @param response AI response to display
     */
    void DisplayAIResponse(const std::string& response);
    
    /**
     * @brief Set script execution callback
     * @param callback Function to call when executing scripts
     */
    void SetExecutionCallback(ExecutionCallback callback);
    
    /**
     * @brief Set save script callback
     * @param callback Function to call when saving scripts
     */
    void SetSaveScriptCallback(SaveScriptCallback callback);
    
    /**
     * @brief Set load scripts callback
     * @param callback Function to call when loading scripts
     */
    void SetLoadScriptsCallback(LoadScriptsCallback callback);
    
    /**
     * @brief Set AI query callback
     * @param callback Function to call when sending AI queries
     */
    void SetAIQueryCallback(AIQueryCallback callback);
    
    /**
     * @brief Set AI response callback
     * @param callback Function to call when receiving AI responses
     */
    void SetAIResponseCallback(AIResponseCallback callback);
    
    /**
     * @brief Get native view controller
     * @return Opaque pointer to native view controller
     */
    void* GetNativeViewController() const;
    
    /**
     * @brief Set native view controller
     * @param viewController Opaque pointer to native view controller
     */
    void SetNativeViewController(void* viewController);

    /**
     * @brief Show the UI
     */
    void Show();
    
    /**
     * @brief Hide the UI
     */
    void Hide();
    
    /**
     * @brief Toggle UI visibility
     * @return True if UI is now visible, false otherwise
     */
    bool Toggle();
    
    /**
     * @brief Check if UI is visible
     * @return True if UI is visible, false otherwise
     */
    bool IsVisible() const;
    
    /**
     * @brief Set the current tab
     * @param tab Tab to switch to
     */
    void SetTab(Tab tab);
    
    /**
     * @brief Get the current tab
     * @return Current tab
     */
    Tab GetCurrentTab() const;
    
    /**
     * @brief Set tab changed callback
     * @param callback Function to call when tab changes
     */
    void SetTabChangedCallback(TabChangedCallback callback);
    
    /**
     * @brief Set visibility changed callback
     * @param callback Function to call when visibility changes
     */
    void SetVisibilityChangedCallback(VisibilityChangedCallback callback);
};

} // namespace UI
} // namespace iOS
