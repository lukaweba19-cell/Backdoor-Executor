#pragma once

#include <string>
#include <unordered_map>
#include <vector>
#include <functional>
#include <memory>

namespace RobloxExecutor {
namespace NamingConventions {

/**
 * @brief Enum representing different naming convention standards
 */
enum class ConventionType {
    UNC,    // Unified Naming Convention
    SNC,    // Salad Naming Convention
    Custom  // Custom naming convention
};

/**
 * @brief Structure to hold function alias information
 */
struct FunctionAlias {
    std::string originalName;     // Original function name in the executor
    std::string aliasName;        // Alias name from a naming convention
    ConventionType convention;    // Which convention this alias belongs to
    std::string description;      // Description of the function
    
    FunctionAlias(const std::string& original, const std::string& alias, 
                 ConventionType conv, const std::string& desc = "")
        : originalName(original), aliasName(alias), convention(conv), description(desc) {}
};

/**
 * @class NamingConventionManager
 * @brief Manages function aliases and naming conventions
 * 
 * This class provides a centralized system for registering and resolving
 * function aliases across different naming conventions.
 */
class NamingConventionManager {
public:
    // Singleton instance
    static NamingConventionManager& GetInstance();
    
    // Delete copy and move constructors/assignments
    NamingConventionManager(const NamingConventionManager&) = delete;
    NamingConventionManager& operator=(const NamingConventionManager&) = delete;
    NamingConventionManager(NamingConventionManager&&) = delete;
    NamingConventionManager& operator=(NamingConventionManager&&) = delete;
    
    /**
     * @brief Initialize the naming convention manager
     * @param enableUNC Enable UNC naming convention
     * @param enableSNC Enable SNC naming convention
     * @return True if initialization succeeded
     */
    bool Initialize(bool enableUNC = true, bool enableSNC = true);
    
    /**
     * @brief Register a function alias
     * @param originalName Original function name
     * @param aliasName Alias name
     * @param convention Which convention this alias belongs to
     * @param description Optional description of the function
     * @return True if registration succeeded
     */
    bool RegisterAlias(const std::string& originalName, const std::string& aliasName,
                      ConventionType convention, const std::string& description = "");
    
    /**
     * @brief Register multiple aliases for a function
     * @param originalName Original function name
     * @param aliases Vector of alias names
     * @param convention Which convention these aliases belong to
     * @param description Optional description of the function
     * @return True if registration succeeded
     */
    bool RegisterAliases(const std::string& originalName, 
                        const std::vector<std::string>& aliases,
                        ConventionType convention,
                        const std::string& description = "");
    
    /**
     * @brief Resolve a function name to its original name
     * @param functionName Function name to resolve (could be an alias)
     * @return Original function name, or empty string if not found
     */
    std::string ResolveFunction(const std::string& functionName) const;
    
    /**
     * @brief Check if a function name is an alias
     * @param functionName Function name to check
     * @return True if the function name is an alias
     */
    bool IsAlias(const std::string& functionName) const;
    
    /**
     * @brief Get all aliases for a function
     * @param originalName Original function name
     * @return Vector of aliases for the function
     */
    std::vector<FunctionAlias> GetAliases(const std::string& originalName) const;
    
    /**
     * @brief Get all function aliases
     * @return Vector of all function aliases
     */
    std::vector<FunctionAlias> GetAllAliases() const;
    
    /**
     * @brief Enable or disable a naming convention
     * @param convention Convention to enable/disable
     * @param enable True to enable, false to disable
     */
    void EnableConvention(ConventionType convention, bool enable);
    
    /**
     * @brief Check if a naming convention is enabled
     * @param convention Convention to check
     * @return True if the convention is enabled
     */
    bool IsConventionEnabled(ConventionType convention) const;
    
private:
    // Private constructor for singleton
    NamingConventionManager();
    
    // Initialize UNC naming convention
    void InitializeUNC();
    
    // Initialize SNC naming convention
    void InitializeSNC();
    
    // Map of function aliases (alias name -> original name)
    std::unordered_map<std::string, std::string> m_aliasMap;
    
    // Map of original names to their aliases (original name -> vector of aliases)
    std::unordered_map<std::string, std::vector<FunctionAlias>> m_originalToAliases;
    
    // Enabled conventions
    bool m_enableUNC;
    bool m_enableSNC;
    bool m_enableCustom;
    
    // Initialization state
    bool m_initialized;
};

} // namespace NamingConventions
} // namespace RobloxExecutor
