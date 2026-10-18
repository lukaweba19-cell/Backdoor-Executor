
#include "../objc_isolation.h"
#pragma once

#include <string>
#include <vector>
#include <functional>
#include <unordered_map>
#include <unordered_set>
#include <memory>
#include "../filesystem_utils.h"

namespace iOS {
    /**
     * @class ScriptManager
     * @brief Manages script storage, loading, and execution
     * 
     * This class provides a comprehensive script management system that works
     * with the FileSystem to store and load scripts. It supports script categories,
     * favorites, history, and more, all while ensuring compatibility with
     * non-jailbroken devices.
     */
    class ScriptManager {
    public:
        // Script category enumeration
        enum class Category {
            General,
            Utilities,
            Combat,
            Movement,
            Visual,
            Game,
            Favorite,
            Recent,
            Custom
        };
        
        // Script structure
        struct Script {
            std::string m_name;             // Script name
            std::string m_content;          // Script content
            std::string m_description;      // Script description
            std::string m_author;           // Script author
            Category m_category;            // Script category
            std::string m_customCategory;   // Custom category name (if category is Custom)
            bool m_isFavorite;              // Is favorite
            uint64_t m_lastExecuted;        // Last executed timestamp
            uint64_t m_created;             // Created timestamp
            uint64_t m_modified;            // Last modified timestamp
            std::string m_filePath;         // File path if loaded from file
            
            Script()
                : m_category(Category::General),
                  m_isFavorite(false),
                  m_lastExecuted(0),
                  m_created(0),
                  m_modified(0) {}
            
            Script(const std::string& name, const std::string& content,
                   const std::string& description = "", const std::string& author = "",
                   Category category = Category::General, bool isFavorite = false)
                : m_name(name),
                  m_content(content),
                  m_description(description),
                  m_author(author),
                  m_category(category),
                  m_isFavorite(isFavorite),
                  m_lastExecuted(0),
                  m_created(0),
                  m_modified(0) {
                
                // Set created timestamp to current time
                m_created = static_cast<uint64_t>(time(nullptr));
                m_modified = m_created;
            }
        };
        
        // Callback for script execution
        using ExecuteCallback = std::function<bool(const Script&)>;
        
    private:
        // Member variables with consistent m_ prefix
        std::vector<Script> m_scripts;
        std::vector<Script> m_recentScripts;
        std::vector<std::string> m_customCategories;
        ExecuteCallback m_executeCallback;
        bool m_encryptScripts;
        int m_maxRecentScripts;
        std::string m_defaultDirectory;
        
        // Private methods
        bool SaveScriptToFile(const Script& script);
        bool LoadScriptFromFile(const std::string& path, Script& script);
        std::string EncryptScript(const std::string& content);
        std::string DecryptScript(const std::string& encrypted);
        std::string GenerateScriptFileName(const Script& script);
        void UpdateRecentScripts(const Script& script);
        Script LoadScriptFromJson(const std::string& json);
        std::string SaveScriptToJson(const Script& script);
        std::string CategoryToString(Category category);
        Category StringToCategory(const std::string& category);
        
    public:
        /**
         * @brief Constructor
         * @param encryptScripts Whether to encrypt scripts when saving
         * @param maxRecentScripts Maximum number of recent scripts to track
         * @param defaultDirectory Default directory for scripts
         */
        ScriptManager(bool encryptScripts = true, int maxRecentScripts = 10,
                     const std::string& defaultDirectory = "Scripts");
        
        /**
         * @brief Initialize script manager
         * @return True if initialization succeeded, false otherwise
         */
        bool Initialize();
        
        /**
         * @brief Add a script
         * @param script Script to add
         * @param save Whether to save the script to file
         * @return True if script was added, false otherwise
         */
        bool AddScript(const Script& script, bool save = true);
        
        /**
         * @brief Save a script with basic info (for UI integration)
         * @param name Script name
         * @param content Script content
         * @return True if saved successfully
         */
        bool SaveScript(const std::string& name, const std::string& content) {
            Script script(name, content);
            return AddScript(script, true);
        }
        
        /**
         * @brief Get all saved scripts in simple format (for UI integration)
         * @return Vector of all scripts
         */
        std::vector<Script> GetSavedScripts() {
            return GetAllScripts();
        }
        
        /**
         * @brief Get a script by name
         * @param name Name of the script to get
         * @return Script if found, or empty script if not found
         */
        Script GetScript(const std::string& name);
        
        /**
         * @brief Get all scripts
         * @return Vector of all scripts
         */
        std::vector<Script> GetAllScripts();
        
        /**
         * @brief Get scripts by category
         * @param category Category to filter by
         * @param customCategory Custom category name (if category is Custom)
         * @return Vector of scripts in the specified category
         */
        std::vector<Script> GetScriptsByCategory(Category category,
                                               const std::string& customCategory = "");
        
        /**
         * @brief Get favorite scripts
         * @return Vector of favorite scripts
         */
        std::vector<Script> GetFavoriteScripts();
        
        /**
         * @brief Get recent scripts
         * @return Vector of recently executed scripts
         */
        std::vector<Script> GetRecentScripts();
        
        /**
         * @brief Update a script
         * @param name Name of the script to update
         * @param script New script data
         * @param save Whether to save the script to file
         * @return True if script was updated, false otherwise
         */
        bool UpdateScript(const std::string& name, const Script& script, bool save = true);
        
        /**
         * @brief Delete a script
         * @param name Name of the script to delete
         * @return True if script was deleted, false otherwise
         */
        bool DeleteScript(const std::string& name);
        
        /**
         * @brief Execute a script
         * @param name Name of the script to execute
         * @return True if execution succeeded, false otherwise
         */
        bool ExecuteScript(const std::string& name);
        
        /**
         * @brief Execute script content directly
         * @param content Script content to execute
         * @param name Optional name for the script
         * @return True if execution succeeded, false otherwise
         */
        bool ExecuteScriptContent(const std::string& content, const std::string& name = "");
        
        /**
         * @brief Set a script as favorite
         * @param name Name of the script
         * @param favorite True to set as favorite, false to unset
         * @return True if operation succeeded, false otherwise
         */
        bool SetFavorite(const std::string& name, bool favorite);
        
        /**
         * @brief Add a custom category
         * @param category Name of the custom category
         * @return True if category was added, false otherwise
         */
        bool AddCustomCategory(const std::string& category);
        
        /**
         * @brief Remove a custom category
         * @param category Name of the custom category
         * @return True if category was removed, false otherwise
         */
        bool RemoveCustomCategory(const std::string& category);
        
        /**
         * @brief Get all custom categories
         * @return Vector of custom category names
         */
        std::vector<std::string> GetCustomCategories();
        
        /**
         * @brief Set script execution callback
         * @param callback Function to call for script execution
         */
        void SetExecuteCallback(ExecuteCallback callback);
        
        /**
         * @brief Enable/disable script encryption
         * @param encrypt True to enable encryption, false to disable
         */
        void SetEncryptScripts(bool encrypt);
        
        /**
         * @brief Get script encryption setting
         * @return True if scripts are encrypted, false otherwise
         */
        bool GetEncryptScripts() const;
        
        /**
         * @brief Set maximum number of recent scripts
         * @param max Maximum number of recent scripts
         */
        void SetMaxRecentScripts(int max);
        
        /**
         * @brief Get maximum number of recent scripts
         * @return Maximum number of recent scripts
         */
        int GetMaxRecentScripts() const;
        
        /**
         * @brief Set default directory for scripts
         * @param directory Default directory
         */
        void SetDefaultDirectory(const std::string& directory);
        
        /**
         * @brief Get default directory for scripts
         * @return Default directory
         */
        std::string GetDefaultDirectory() const;
        
        /**
         * @brief Load all scripts from the scripts directory
         * @return True if load succeeded, false otherwise
         */
        bool LoadAllScripts();
        
        /**
         * @brief Save all scripts to the scripts directory
         * @return True if save succeeded, false otherwise
         */
        bool SaveAllScripts();
        
        /**
         * @brief Clear all scripts
         */
        void ClearScripts();
        
        /**
         * @brief Search for scripts by name or content
         * @param query Search query
         * @return Vector of matching scripts
         */
        std::vector<Script> SearchScripts(const std::string& query);
        
        /**
         * @brief Import a script from file
         * @param path Path to the script file
         * @return True if import succeeded, false otherwise
         */
        bool ImportScript(const std::string& path);
        
        /**
         * @brief Export a script to file
         * @param name Name of the script to export
         * @param path Path to export to
         * @return True if export succeeded, false otherwise
         */
        bool ExportScript(const std::string& name, const std::string& path);
    };
}
