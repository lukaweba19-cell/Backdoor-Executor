#include "function_resolver.h"
#include <iostream>

namespace RobloxExecutor {
namespace NamingConventions {

// Singleton instance implementation
FunctionResolver& FunctionResolver::GetInstance() {
    static FunctionResolver instance;
    return instance;
}

// Constructor
FunctionResolver::FunctionResolver()
    : m_namingConventionManager(NamingConventionManager::GetInstance()),
      m_initialized(false) {
}

// Initialize the function resolver
bool FunctionResolver::Initialize() {
    if (m_initialized) {
        std::cout << "FunctionResolver: Already initialized" << std::endl;
        return true;
    }
    
    // Make sure the naming convention manager is initialized
    if (!m_namingConventionManager.Initialize()) {
        std::cerr << "FunctionResolver: Failed to initialize naming convention manager" << std::endl;
        return false;
    }
    
    m_initialized = true;
    std::cout << "FunctionResolver: Initialized" << std::endl;
    
    return true;
}

// Register a function with its original name
bool FunctionResolver::RegisterFunction(const std::string& originalName, FunctionType function) {
    // Check if the function is already registered
    if (m_functions.find(originalName) != m_functions.end()) {
        std::cerr << "FunctionResolver: Function '" << originalName << "' already registered" << std::endl;
        return false;
    }
    
    // Register the function
    m_functions[originalName] = function;
    
    return true;
}

// Resolve a function name and get the function
FunctionResolver::FunctionType FunctionResolver::ResolveFunction(const std::string& functionName) const {
    // Resolve the function name to its original name
    std::string originalName = m_namingConventionManager.ResolveFunction(functionName);
    
    // Check if the function is registered
    auto it = m_functions.find(originalName);
    if (it != m_functions.end()) {
        return it->second;
    }
    
    // Function not found
    return nullptr;
}

// Check if a function is registered
bool FunctionResolver::IsFunctionRegistered(const std::string& functionName) const {
    // Resolve the function name to its original name
    std::string originalName = m_namingConventionManager.ResolveFunction(functionName);
    
    // Check if the function is registered
    return m_functions.find(originalName) != m_functions.end();
}

// Get all registered function names
std::vector<std::string> FunctionResolver::GetRegisteredFunctions() const {
    std::vector<std::string> functionNames;
    
    for (const auto& pair : m_functions) {
        functionNames.push_back(pair.first);
    }
    
    return functionNames;
}

} // namespace NamingConventions
} // namespace RobloxExecutor
