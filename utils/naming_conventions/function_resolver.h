#pragma once

#include "naming_conventions.h"
#include <string>
#include <functional>
#include <unordered_map>
#include <memory>

namespace RobloxExecutor {
namespace NamingConventions {

/**
 * @class FunctionResolver
 * @brief Resolves function names and executes the appropriate function
 * 
 * This class provides a mechanism to register functions with their original names
 * and then resolve and execute them when called with any of their aliases.
 */
class FunctionResolver {
public:
    // Function type for C++ functions
    using FunctionType = std::function<void*()>;
    
    // Singleton instance
    static FunctionResolver& GetInstance();
    
    // Delete copy and move constructors/assignments
    FunctionResolver(const FunctionResolver&) = delete;
    FunctionResolver& operator=(const FunctionResolver&) = delete;
    FunctionResolver(FunctionResolver&&) = delete;
    FunctionResolver& operator=(FunctionResolver&&) = delete;
    
    /**
     * @brief Initialize the function resolver
     * @return True if initialization succeeded
     */
    bool Initialize();
    
    /**
     * @brief Register a function with its original name
     * @param originalName Original function name
     * @param function Function to execute
     * @return True if registration succeeded
     */
    bool RegisterFunction(const std::string& originalName, FunctionType function);
    
    /**
     * @brief Resolve a function name and get the function
     * @param functionName Function name to resolve (could be an alias)
     * @return Function to execute, or nullptr if not found
     */
    FunctionType ResolveFunction(const std::string& functionName) const;
    
    /**
     * @brief Check if a function is registered
     * @param functionName Function name to check (could be an alias)
     * @return True if the function is registered
     */
    bool IsFunctionRegistered(const std::string& functionName) const;
    
    /**
     * @brief Get all registered function names
     * @return Vector of all registered function names
     */
    std::vector<std::string> GetRegisteredFunctions() const;
    
private:
    // Private constructor for singleton
    FunctionResolver();
    
    // Map of original function names to functions
    std::unordered_map<std::string, FunctionType> m_functions;
    
    // Reference to the naming convention manager
    NamingConventionManager& m_namingConventionManager;
    
    // Initialization state
    bool m_initialized;
};

} // namespace NamingConventions
} // namespace RobloxExecutor
