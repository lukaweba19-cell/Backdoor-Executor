
#include "../ios_compat.h"
#include "ScriptManager.h"
#include <iostream>
#include <fstream>
#include <sstream>
#include <algorithm>
#include <chrono>
#import <CommonCrypto/CommonCrypto.h>

namespace iOS {
    // Constructor
    ScriptManager::ScriptManager(bool encryptScripts, int maxRecentScripts,
                              const std::string& defaultDirectory)
        : m_encryptScripts(encryptScripts),
          m_maxRecentScripts(maxRecentScripts),
          m_defaultDirectory(defaultDirectory) {
    }
    
    // Initialize script manager
    bool ScriptManager::Initialize() {
        // Ensure FileSystem is initialized
        if (!FileUtils::GetDocumentsPath().empty()) {
            // Load all scripts
            return LoadAllScripts();
        } else {
            std::cerr << "ScriptManager: FileSystem not initialized" << std::endl;
            return false;
        }
    }
    
    // Add a script
    bool ScriptManager::AddScript(const Script& script, bool save) {
        // Check if a script with the same name already exists
        for (const auto& existingScript : m_scripts) {
            if (existingScript.m_name == script.m_name) {
                std::cerr << "ScriptManager: Script with name '" << script.m_name << "' already exists" << std::endl;
                return false;
            }
        }
        
        // Add the script
        m_scripts.push_back(script);
        
        // Save the script to file if requested
        if (save) {
            if (!SaveScriptToFile(script)) {
                std::cerr << "ScriptManager: Failed to save script '" << script.m_name << "' to file" << std::endl;
                // Continue anyway, script is in memory
            }
        }
        
        return true;
    }
    
    // Get a script by name
    ScriptManager::Script ScriptManager::GetScript(const std::string& name) {
        for (const auto& script : m_scripts) {
            if (script.m_name == name) {
                return script;
            }
        }
        
        return Script(); // Return empty script if not found
    }
    
    // Get all scripts
    std::vector<ScriptManager::Script> ScriptManager::GetAllScripts() {
        return m_scripts;
    }
    
    // Get scripts by category
    std::vector<ScriptManager::Script> ScriptManager::GetScriptsByCategory(
        Category category, const std::string& customCategory) {
        
        std::vector<Script> result;
        
        for (const auto& script : m_scripts) {
            if (script.m_category == category) {
                if (category != Category::Custom || script.m_customCategory == customCategory) {
                    result.push_back(script);
                }
            }
        }
        
        return result;
    }
    
    // Get favorite scripts
    std::vector<ScriptManager::Script> ScriptManager::GetFavoriteScripts() {
        std::vector<Script> result;
        
        for (const auto& script : m_scripts) {
            if (script.m_isFavorite) {
                result.push_back(script);
            }
        }
        
        return result;
    }
    
    // Get recent scripts
    std::vector<ScriptManager::Script> ScriptManager::GetRecentScripts() {
        return m_recentScripts;
    }
    
    // Update a script
    bool ScriptManager::UpdateScript(const std::string& name, const Script& script, bool save) {
        // Find the script
        for (auto& existingScript : m_scripts) {
            if (existingScript.m_name == name) {
                // Update the script
                existingScript = script;
                
                // Update modified timestamp
                existingScript.m_modified = static_cast<uint64_t>(time(nullptr));
                
                // Save the script to file if requested
                if (save) {
                    if (!SaveScriptToFile(existingScript)) {
                        std::cerr << "ScriptManager: Failed to save updated script '" << name << "' to file" << std::endl;
                        // Continue anyway, script is updated in memory
                    }
                }
                
                return true;
            }
        }
        
        std::cerr << "ScriptManager: Script '" << name << "' not found for update" << std::endl;
        return false;
    }
    
    // Delete a script
    bool ScriptManager::DeleteScript(const std::string& name) {
        // Find the script
        for (auto it = m_scripts.begin(); it != m_scripts.end(); ++it) {
            if (it->m_name == name) {
                // Delete the script file if it has a file path
                if (!it->m_filePath.empty() && FileUtils::Exists(it->m_filePath)) {
                    if (!FileUtils::Delete(it->m_filePath)) {
                        std::cerr << "ScriptManager: Failed to delete script file '" << it->m_filePath << "'" << std::endl;
                        // Continue anyway, script will be removed from memory
                    }
                }
                
                // Remove from recent scripts if present
                for (auto recIt = m_recentScripts.begin(); recIt != m_recentScripts.end(); ++recIt) {
                    if (recIt->m_name == name) {
                        m_recentScripts.erase(recIt);
                        break;
                    }
                }
                
                // Remove the script from memory
                m_scripts.erase(it);
                return true;
            }
        }
        
        std::cerr << "ScriptManager: Script '" << name << "' not found for deletion" << std::endl;
        return false;
    }
    
    // Execute a script
    bool ScriptManager::ExecuteScript(const std::string& name) {
        // Find the script
        for (auto& script : m_scripts) {
            if (script.m_name == name) {
                // Update last executed timestamp
                script.m_lastExecuted = static_cast<uint64_t>(time(nullptr));
                
                // Add to recent scripts
                UpdateRecentScripts(script);
                
                // Execute the script
                if (m_executeCallback) {
                    return m_executeCallback(script);
                } else {
                    std::cerr << "ScriptManager: No execute callback set" << std::endl;
                    return false;
                }
            }
        }
        
        std::cerr << "ScriptManager: Script '" << name << "' not found for execution" << std::endl;
        return false;
    }
    
    // Execute script content directly
    bool ScriptManager::ExecuteScriptContent(const std::string& content, const std::string& name) {
        // Create a temporary script
        Script script(name.empty() ? "Unnamed Script" : name, content);
        
        // Add to recent scripts
        UpdateRecentScripts(script);
        
        // Execute the script
        if (m_executeCallback) {
            return m_executeCallback(script);
        } else {
            std::cerr << "ScriptManager: No execute callback set" << std::endl;
            return false;
        }
    }
    
    // Set a script as favorite
    bool ScriptManager::SetFavorite(const std::string& name, bool favorite) {
        // Find the script
        for (auto& script : m_scripts) {
            if (script.m_name == name) {
                // Update favorite status
                script.m_isFavorite = favorite;
                
                // Save the script to file
                if (!SaveScriptToFile(script)) {
                    std::cerr << "ScriptManager: Failed to save script '" << name << "' after changing favorite status" << std::endl;
                    // Continue anyway, script is updated in memory
                }
                
                return true;
            }
        }
        
        std::cerr << "ScriptManager: Script '" << name << "' not found for setting favorite" << std::endl;
        return false;
    }
    
    // Add a custom category
    bool ScriptManager::AddCustomCategory(const std::string& category) {
        // Check if the category already exists
        for (const auto& existingCategory : m_customCategories) {
            if (existingCategory == category) {
                return true; // Already exists
            }
        }
        
        // Add the category
        m_customCategories.push_back(category);
        return true;
    }
    
    // Remove a custom category
    bool ScriptManager::RemoveCustomCategory(const std::string& category) {
        // Find the category
        for (auto it = m_customCategories.begin(); it != m_customCategories.end(); ++it) {
            if (*it == category) {
                // Remove the category
                m_customCategories.erase(it);
                return true;
            }
        }
        
        return false; // Category not found
    }
    
    // Get all custom categories
    std::vector<std::string> ScriptManager::GetCustomCategories() {
        return m_customCategories;
    }
    
    // Set script execution callback
    void ScriptManager::SetExecuteCallback(ExecuteCallback callback) {
        m_executeCallback = callback;
    }
    
    // Enable/disable script encryption
    void ScriptManager::SetEncryptScripts(bool encrypt) {
        m_encryptScripts = encrypt;
    }
    
    // Get script encryption setting
    bool ScriptManager::GetEncryptScripts() const {
        return m_encryptScripts;
    }
    
    // Set maximum number of recent scripts
    void ScriptManager::SetMaxRecentScripts(int max) {
        m_maxRecentScripts = max;
        
        // Trim recent scripts if needed
        while (m_recentScripts.size() > static_cast<size_t>(m_maxRecentScripts)) {
            m_recentScripts.pop_back();
        }
    }
    
    // Get maximum number of recent scripts
    int ScriptManager::GetMaxRecentScripts() const {
        return m_maxRecentScripts;
    }
    
    // Set default directory for scripts
    void ScriptManager::SetDefaultDirectory(const std::string& directory) {
        m_defaultDirectory = directory;
    }
    
    // Get default directory for scripts
    std::string ScriptManager::GetDefaultDirectory() const {
        return m_defaultDirectory;
    }
    
    // Load all scripts from the scripts directory
    bool ScriptManager::LoadAllScripts() {
        // Clear existing scripts
        m_scripts.clear();
        
        // Get the scripts directory
        std::string scriptsDir = FileUtils::GetScriptsPath();
        if (scriptsDir.empty()) {
            std::cerr << "ScriptManager: Scripts directory not set" << std::endl;
            return false;
        }
        
        // List all files in the scripts directory
        std::vector<FileUtils::FileInfo> files = FileUtils::ListDirectory(scriptsDir);
        
        // Load each script file
        for (const auto& file : files) {
            // Only load .lua and .json files
            if (file.m_type == FileUtils::Regular) {
                std::string extension = file.m_path.substr(file.m_path.find_last_of('.') + 1);
                std::transform(extension.begin(), extension.end(), extension.begin(), ::tolower);
                
                if (extension == "lua" || extension == "txt" || extension == "json") {
                    Script script;
                    if (LoadScriptFromFile(file.m_path, script)) {
                        m_scripts.push_back(script);
                    }
                }
            }
        }
        
        std::cout << "ScriptManager: Loaded " << m_scripts.size() << " scripts" << std::endl;
        return true;
    }
    
    // Save all scripts to the scripts directory
    bool ScriptManager::SaveAllScripts() {
        bool allSaved = true;
        
        // Save each script
        for (const auto& script : m_scripts) {
            if (!SaveScriptToFile(script)) {
                std::cerr << "ScriptManager: Failed to save script '" << script.m_name << "'" << std::endl;
                allSaved = false;
            }
        }
        
        return allSaved;
    }
    
    // Clear all scripts
    void ScriptManager::ClearScripts() {
        m_scripts.clear();
        m_recentScripts.clear();
    }
    
    // Search for scripts by name or content
    std::vector<ScriptManager::Script> ScriptManager::SearchScripts(const std::string& query) {
        std::vector<Script> result;
        
        // Convert query to lowercase for case-insensitive search
        std::string lowerQuery = query;
        std::transform(lowerQuery.begin(), lowerQuery.end(), lowerQuery.begin(), ::tolower);
        
        for (const auto& script : m_scripts) {
            // Convert script name and content to lowercase
            std::string lowerName = script.m_name;
            std::transform(lowerName.begin(), lowerName.end(), lowerName.begin(), ::tolower);
            
            std::string lowerContent = script.m_content;
            std::transform(lowerContent.begin(), lowerContent.end(), lowerContent.begin(), ::tolower);
            
            // Check if query is in name or content
            if (lowerName.find(lowerQuery) != std::string::npos ||
                lowerContent.find(lowerQuery) != std::string::npos) {
                result.push_back(script);
            }
        }
        
        return result;
    }
    
    // Import a script from file
    bool ScriptManager::ImportScript(const std::string& path) {
        // Check if file exists
        if (!FileUtils::Exists(path)) {
            std::cerr << "ScriptManager: Import file does not exist: " << path << std::endl;
            return false;
        }
        
        // Load the script
        Script script;
        if (!LoadScriptFromFile(path, script)) {
            std::cerr << "ScriptManager: Failed to load script from import file: " << path << std::endl;
            return false;
        }
        
        // Add the script
        return AddScript(script, true);
    }
    
    // Export a script to file
    bool ScriptManager::ExportScript(const std::string& name, const std::string& path) {
        // Find the script
        Script script = GetScript(name);
        if (script.m_name.empty()) {
            std::cerr << "ScriptManager: Script '" << name << "' not found for export" << std::endl;
            return false;
        }
        
        // Ensure parent directory exists
        std::string parentDir = path.substr(0, path.find_last_of('/'));
        if (!FileUtils::EnsureDirectoryExists(parentDir)) {
            std::cerr << "ScriptManager: Failed to ensure parent directory exists: " << parentDir << std::endl;
            return false;
        }
        
        // Save the script
        return FileUtils::WriteFile(path, script.m_content, false);
    }
    
    // Save a script to file
    bool ScriptManager::SaveScriptToFile(const Script& script) {
        // Generate a file path if the script doesn't have one
        std::string filePath = script.m_filePath;
        if (filePath.empty()) {
            // Get the scripts directory
            std::string scriptsDir = FileUtils::GetScriptsPath();
            if (scriptsDir.empty()) {
                std::cerr << "ScriptManager: Scripts directory not set" << std::endl;
                return false;
            }
            
            // Generate a file name
            std::string fileName = GenerateScriptFileName(script);
            filePath = FileUtils::CombinePaths(scriptsDir, fileName);
        }
        
        // Convert script to JSON
        std::string json = SaveScriptToJson(script);
        
        // Encrypt the JSON if encryption is enabled
        std::string content = json;
        if (m_encryptScripts) {
            content = EncryptScript(json);
        }
        
        // Save the file
        return FileUtils::WriteFile(filePath, content, false);
    }
    
    // Load a script from file
    bool ScriptManager::LoadScriptFromFile(const std::string& path, Script& script) {
        // Read the file
        std::string content = FileUtils::ReadFile(path);
        if (content.empty()) {
            std::cerr << "ScriptManager: Failed to read file: " << path << std::endl;
            return false;
        }
        
        // Check if content is encrypted
        bool isEncrypted = false;
        if (content.size() > 16) { // Minimum size for encrypted content
            // Encrypted content will start with a specific marker or have specific patterns
            // This is a simple heuristic; a real implementation would have better detection
            isEncrypted = (content[0] == '{' && content[1] == 'E' && content[2] == 'N' && content[3] == 'C');
        }
        
        std::string decryptedContent = content;
        if (isEncrypted) {
            decryptedContent = DecryptScript(content);
        }
        
        // Check file extension
        std::string extension = path.substr(path.find_last_of('.') + 1);
        std::transform(extension.begin(), extension.end(), extension.begin(), ::tolower);
        
        if (extension == "json") {
            // Parse JSON
            script = LoadScriptFromJson(decryptedContent);
        } else {
            // Treat as plain text script
            // Extract name from file name
            std::string fileName = path.substr(path.find_last_of('/') + 1);
            std::string name = fileName.substr(0, fileName.find_last_of('.'));
            
            // Create script
            script = Script(name, decryptedContent);
        }
        
        // Set file path
        script.m_filePath = path;
        
        return true;
    }
    
    // Encrypt a script
    std::string ScriptManager::EncryptScript(const std::string& content) {
        // In a real implementation, use proper encryption
        // This is a simple XOR encryption for demonstration
        
        // Generate a random key
        uint8_t key = static_cast<uint8_t>(rand() % 256);
        
        // Encrypt with XOR
        std::string encrypted = "{ENC}"; // Marker for encrypted content
        encrypted += static_cast<char>(key); // Add key as first byte
        
        for (char c : content) {
            encrypted += static_cast<char>(c ^ key);
        }
        
        return encrypted;
    }
    
    // Decrypt a script
    std::string ScriptManager::DecryptScript(const std::string& encrypted) {
        // Check for encryption marker
        if (encrypted.size() <= 5 || encrypted.substr(0, 5) != "{ENC}") {
            return encrypted; // Not encrypted or invalid format
        }
        
        // Extract key
        uint8_t key = static_cast<uint8_t>(encrypted[5]);
        
        // Decrypt with XOR
        std::string decrypted;
        for (size_t i = 6; i < encrypted.size(); i++) {
            decrypted += static_cast<char>(encrypted[i] ^ key);
        }
        
        return decrypted;
    }
    
    // Generate a file name for a script
    std::string ScriptManager::GenerateScriptFileName(const Script& script) {
        // Create a safe file name from the script name
        std::string safeName = script.m_name;
        
        // Replace invalid characters
        std::replace_if(safeName.begin(), safeName.end(), [](char c) {
            return c == '/' || c == '\\' || c == ':' || c == '*' || c == '?' || c == '"' || c == '<' || c == '>' || c == '|';
        }, '_');
        
        // Add extension
        return safeName + ".json";
    }
    
    // Update recent scripts list
    void ScriptManager::UpdateRecentScripts(const Script& script) {
        // Check if the script is already in the recent list
        for (auto it = m_recentScripts.begin(); it != m_recentScripts.end(); ++it) {
            if (it->m_name == script.m_name) {
                // Move to front
                Script temp = *it;
                temp.m_lastExecuted = static_cast<uint64_t>(time(nullptr));
                m_recentScripts.erase(it);
                m_recentScripts.insert(m_recentScripts.begin(), temp);
                return;
            }
        }
        
        // Add to front of list
        Script recentScript = script;
        recentScript.m_lastExecuted = static_cast<uint64_t>(time(nullptr));
        m_recentScripts.insert(m_recentScripts.begin(), recentScript);
        
        // Trim if needed
        while (m_recentScripts.size() > static_cast<size_t>(m_maxRecentScripts)) {
            m_recentScripts.pop_back();
        }
    }
    
    // Load a script from JSON
    ScriptManager::Script ScriptManager::LoadScriptFromJson(const std::string& json) {
        // Parse JSON
        NSError* error = nil;
        NSData* jsonData = [NSData dataWithBytes:json.c_str() length:json.size()];
        NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        
        if (error || ![dict isKindOfClass:[NSDictionary class]]) {
            std::cerr << "ScriptManager: Failed to parse JSON" << std::endl;
            return Script();
        }
        
        // Extract script properties
        Script script;
        
        NSString* name = [dict objectForKey:@"name"];
        if (name && [name isKindOfClass:[NSString class]]) {
            script.m_name = [name UTF8String];
        }
        
        NSString* content = [dict objectForKey:@"content"];
        if (content && [content isKindOfClass:[NSString class]]) {
            script.m_content = [content UTF8String];
        }
        
        NSString* description = [dict objectForKey:@"description"];
        if (description && [description isKindOfClass:[NSString class]]) {
            script.m_description = [description UTF8String];
        }
        
        NSString* author = [dict objectForKey:@"author"];
        if (author && [author isKindOfClass:[NSString class]]) {
            script.m_author = [author UTF8String];
        }
        
        NSString* category = [dict objectForKey:@"category"];
        if (category && [category isKindOfClass:[NSString class]]) {
            script.m_category = StringToCategory([category UTF8String]);
        }
        
        NSString* customCategory = [dict objectForKey:@"customCategory"];
        if (customCategory && [customCategory isKindOfClass:[NSString class]]) {
            script.m_customCategory = [customCategory UTF8String];
        }
        
        NSNumber* isFavorite = [dict objectForKey:@"isFavorite"];
        if (isFavorite && [isFavorite isKindOfClass:[NSNumber class]]) {
            script.m_isFavorite = [isFavorite boolValue];
        }
        
        NSNumber* lastExecuted = [dict objectForKey:@"lastExecuted"];
        if (lastExecuted && [lastExecuted isKindOfClass:[NSNumber class]]) {
            script.m_lastExecuted = [lastExecuted unsignedLongLongValue];
        }
        
        NSNumber* created = [dict objectForKey:@"created"];
        if (created && [created isKindOfClass:[NSNumber class]]) {
            script.m_created = [created unsignedLongLongValue];
        }
        
        NSNumber* modified = [dict objectForKey:@"modified"];
        if (modified && [modified isKindOfClass:[NSNumber class]]) {
            script.m_modified = [modified unsignedLongLongValue];
        }
        
        return script;
    }
    
    // Save a script to JSON
    std::string ScriptManager::SaveScriptToJson(const Script& script) {
        // Create JSON dictionary
        NSMutableDictionary* dict = [NSMutableDictionary dictionary];
        
        [dict setObject:[NSString stringWithUTF8String:script.m_name.c_str()] forKey:@"name"];
        [dict setObject:[NSString stringWithUTF8String:script.m_content.c_str()] forKey:@"content"];
        
        if (!script.m_description.empty()) {
            [dict setObject:[NSString stringWithUTF8String:script.m_description.c_str()] forKey:@"description"];
        }
        
        if (!script.m_author.empty()) {
            [dict setObject:[NSString stringWithUTF8String:script.m_author.c_str()] forKey:@"author"];
        }
        
        [dict setObject:[NSString stringWithUTF8String:CategoryToString(script.m_category).c_str()] forKey:@"category"];
        
        if (!script.m_customCategory.empty()) {
            [dict setObject:[NSString stringWithUTF8String:script.m_customCategory.c_str()] forKey:@"customCategory"];
        }
        
        [dict setObject:[NSNumber numberWithBool:script.m_isFavorite] forKey:@"isFavorite"];
        [dict setObject:[NSNumber numberWithUnsignedLongLong:script.m_lastExecuted] forKey:@"lastExecuted"];
        [dict setObject:[NSNumber numberWithUnsignedLongLong:script.m_created] forKey:@"created"];
        [dict setObject:[NSNumber numberWithUnsignedLongLong:script.m_modified] forKey:@"modified"];
        
        // Convert to JSON
        NSError* error = nil;
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
        
        if (error) {
            std::cerr << "ScriptManager: Failed to create JSON" << std::endl;
            return "{}";
        }
        
        // Convert to string
        NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        return [jsonString UTF8String];
    }
    
    // Convert category enum to string
    std::string ScriptManager::CategoryToString(Category category) {
        switch (category) {
            case Category::General:
                return "General";
            case Category::Utilities:
                return "Utilities";
            case Category::Combat:
                return "Combat";
            case Category::Movement:
                return "Movement";
            case Category::Visual:
                return "Visual";
            case Category::Game:
                return "Game";
            case Category::Favorite:
                return "Favorite";
            case Category::Recent:
                return "Recent";
            case Category::Custom:
                return "Custom";
            default:
                return "General";
        }
    }
    
    // Convert string to category enum
    ScriptManager::Category ScriptManager::StringToCategory(const std::string& category) {
        if (category == "Utilities") {
            return Category::Utilities;
        } else if (category == "Combat") {
            return Category::Combat;
        } else if (category == "Movement") {
            return Category::Movement;
        } else if (category == "Visual") {
            return Category::Visual;
        } else if (category == "Game") {
            return Category::Game;
        } else if (category == "Favorite") {
            return Category::Favorite;
        } else if (category == "Recent") {
            return Category::Recent;
        } else if (category == "Custom") {
            return Category::Custom;
        } else {
            return Category::General;
        }
    }
}
