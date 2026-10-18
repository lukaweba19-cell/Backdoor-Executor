#pragma once

#include "naming_conventions.h"
#include "function_resolver.h"
#include <string>
#include <vector>
#include <unordered_set>

namespace RobloxExecutor {
namespace NamingConventions {

/**
 * @class ScriptPreprocessor
 * @brief Preprocesses scripts to handle naming conventions
 * 
 * This class provides functionality to preprocess scripts to handle
 * different naming conventions, including function name resolution
 * and alias handling.
 */
class ScriptPreprocessor {
public:
    // Singleton instance
    static ScriptPreprocessor& GetInstance();
    
    // Delete copy and move constructors/assignments
    ScriptPreprocessor(const ScriptPreprocessor&) = delete;
    ScriptPreprocessor& operator=(const ScriptPreprocessor&) = delete;
    ScriptPreprocessor(ScriptPreprocessor&&) = delete;
    ScriptPreprocessor& operator=(ScriptPreprocessor&&) = delete;
    
    /**
     * @brief Initialize the script preprocessor
     * @return True if initialization succeeded
     */
    bool Initialize();
    
    /**
     * @brief Preprocess a script to handle naming conventions
     * @param script Script to preprocess
     * @return Preprocessed script
     */
    std::string PreprocessScript(const std::string& script);
    
    /**
     * @brief Generate compatibility layer code for all naming conventions
     * @return Compatibility layer code
     */
    std::string GenerateCompatibilityLayer();
    
private:
    // Private constructor for singleton
    ScriptPreprocessor();
    
    // Reference to the naming convention manager
    NamingConventionManager& m_namingConventionManager;
    
    // Reference to the function resolver
    FunctionResolver& m_functionResolver;
    
    // Initialization state
    bool m_initialized;
    
    // Generate compatibility layer for a specific function
    std::string GenerateFunctionCompatibilityLayer(const std::string& originalName, 
                                                 const std::vector<FunctionAlias>& aliases);
    
    // Parse a script to find function calls
    std::unordered_set<std::string> FindFunctionCalls(const std::string& script);
};

} // namespace NamingConventions
} // namespace RobloxExecutor
