#include "../../ios_compat.h"
#include "DynamicMessageDispatcher.h"
#include <string>
#include <iostream>

namespace iOS {
namespace AdvancedBypass {

    // Implementation of key methods

    bool DynamicMessageDispatcher::IsAvailable() {
        return true;  // Simple implementation for build fix
    }

    std::string DynamicMessageDispatcher::ExecuteScript(const std::string& script) {
        // Wrapper for Execute that returns just the output
        ExecutionResult result = Execute(script);
        return result.m_output;
    }

} // namespace AdvancedBypass
} // namespace iOS
