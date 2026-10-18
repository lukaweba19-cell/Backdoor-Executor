
#include "../objc_isolation.h"
#pragma once

#include <string>
#include <functional>
#include <vector>
#include <memory>
#include "FloatingButtonController.h"

namespace iOS {
    // Forward declaration of UI namespace
    namespace UI {
        class MainViewController;
    }
    
    /**
     * @class UIController
     * @brief Controls the main executor UI on iOS
     * 
     * This class manages the entire UI for the executor, including the script editor,
     * script management, and execution controls. It provides a touch-optimized 
     * interface specifically designed for iOS devices.
     */
    class UIController {
    public:
        // Tab types
        enum class TabType {
            Editor,
            Scripts,
            Console,
            Settings
        };
        
        // Script information structure
        struct ScriptInfo {
            std::string m_name;
            std::string m_content;
            int64_t m_timestamp;
            
            // Default constructor
            ScriptInfo() : m_name(""), m_content(""), m_timestamp(0) {}
            
            ScriptInfo(const std::string& name, const std::string& content, int64_t timestamp = 0)
                : m_name(name), m_content(content), m_timestamp(timestamp) {}
        };
        
        // Callback typedefs
        using ExecuteCallback = std::function<bool(const std::string&)>;
        using SaveScriptCallback = std::function<bool(const ScriptInfo&)>;
        using LoadScriptsCallback = std::function<std::vector<ScriptInfo>()>;
        
    private:
        // Member variables with consistent m_ prefix
        void* m_uiView; // Opaque pointer to UIView
        std::unique_ptr<FloatingButtonController> m_floatingButton;
        bool m_isVisible;
        TabType m_currentTab;
        float m_opacity;
        bool m_isDraggable;
        std::string m_currentScript;
        std::vector<ScriptInfo> m_savedScripts;
        std::string m_consoleText;
        
        // Callbacks
        ExecuteCallback m_executeCallback;
        SaveScriptCallback m_saveScriptCallback;
        LoadScriptsCallback m_loadScriptsCallback;
        
        // Private methods
        void CreateUI();
        void UpdateLayout();
        void SaveUIState();
        void LoadUIState();
        void RefreshScriptsList();
        void AppendToConsole(const std::string& text);
        
    public:
        /**
         * @brief Constructor
         */
        UIController();
        
        /**
         * @brief Destructor
         */
        ~UIController();
        
        /**
         * @brief Initialize the UI
         * @return True if initialization succeeded, false otherwise
         */
        bool Initialize();
        
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
         * @return New visibility state
         */
        bool Toggle();
        
        /**
         * @brief Check if UI is visible
         * @return True if visible, false otherwise
         */
        bool IsVisible() const;
        
        /**
         * @brief Switch to a specific tab
         * @param tab The tab to switch to
         */
        void SwitchTab(TabType tab);
        
        /**
         * @brief Get current tab
         * @return Current tab
         */
        TabType GetCurrentTab() const;
        
        /**
         * @brief Set UI opacity
         * @param opacity New opacity (0.0 - 1.0)
         */
        void SetOpacity(float opacity);
        
        /**
         * @brief Get UI opacity
         * @return Current opacity
         */
        float GetOpacity() const;
        
        /**
         * @brief Enable/disable UI dragging
         * @param enabled True to enable dragging, false to disable
         */
        void SetDraggable(bool enabled);
        
        /**
         * @brief Check if UI is draggable
         * @return True if draggable, false otherwise
         */
        bool IsDraggable() const;
        
        /**
         * @brief Set script content in editor
         * @param script Script content
         */
        void SetScriptContent(const std::string& script);
        
        /**
         * @brief Get script content from editor
         * @return Current script content
         */
        std::string GetScriptContent() const;
        
        /**
         * @brief Execute current script in editor
         * @return True if execution succeeded, false otherwise
         */
        bool ExecuteCurrentScript();
        
        /**
         * @brief Save current script in editor
         * @param name Name to save script as (empty for auto-generated name)
         * @return True if save succeeded, false otherwise
         */
        bool SaveCurrentScript(const std::string& name = "");
        
        /**
         * @brief Load a script into the editor
         * @param scriptInfo Script to load
         * @return True if load succeeded, false otherwise
         */
        bool LoadScript(const ScriptInfo& scriptInfo);
        
        /**
         * @brief Delete a saved script
         * @param name Name of script to delete
         * @return True if deletion succeeded, false otherwise
         */
        bool DeleteScript(const std::string& name);
        
        /**
         * @brief Clear the console
         */
        void ClearConsole();
        
        /**
         * @brief Get console text
         * @return Current console text
         */
        std::string GetConsoleText() const;
        
        /**
         * @brief Set execute callback
         * @param callback Function to call when executing a script
         */
        void SetExecuteCallback(ExecuteCallback callback);
        
        /**
         * @brief Set save script callback
         * @param callback Function to call when saving a script
         */
        void SetSaveScriptCallback(SaveScriptCallback callback);
        
        /**
         * @brief Set load scripts callback
         * @param callback Function to call when loading scripts
         */
        void SetLoadScriptsCallback(LoadScriptsCallback callback);
        
        /**
         * @brief Check if button is visible
         * @return True if visible, false otherwise
         */
        bool IsButtonVisible() const;
        
        /**
         * @brief Show/hide floating button
         * @param visible True to show, false to hide
         */
        void SetButtonVisible(bool visible);
        
        /**
         * @brief Get the main view controller
         * @return Shared pointer to main view controller
         */
        std::shared_ptr<UI::MainViewController> GetMainViewController() const {
            // Implementation inline to avoid linking issues
            return std::shared_ptr<UI::MainViewController>();
        }
    };
}
