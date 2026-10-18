#include "../../memory/ci_compat.h"
#include "WebKitExploit.h"
#include "MethodSwizzlingExploit.h"
#include "DynamicMessageDispatcher.h"
#include "LoadstringSupport.h"
#include "../../ios_compat.h"
#include "ExecutionIntegration.h"
#include <string>
#include <memory>
#include <vector>
#include <map>
#include <functional>
#include <mutex>
#include <iostream>
#include <chrono>
#include <algorithm>

// Include headers
#include "../GameDetector.h"
#include "../../hooks/hooks.hpp"
#include "../../memory/mem.hpp"
#include "../../memory/signature.hpp"
#include "../PatternScanner.h"

namespace iOS {
    namespace AdvancedBypass {

        // Helper function to get current timestamp
        static uint64_t GetCurrentTimeMs() {
            return std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::system_clock::now().time_since_epoch()).count();
        }

        // Implementation of ExecutionIntegration
        ExecutionIntegration::ExecutionIntegration(Method method)
            : m_primaryMethod(method),
              m_webKit(nullptr),
              m_methodSwizzling(nullptr),
              m_dynamicMessage(nullptr),
              m_loadstring(nullptr),
              m_loadstringInjected(false) {
            
            std::cout << "ExecutionIntegration: Creating with method " 
                      << MethodToString(method) << std::endl;
                      
            // Setup fallback chain if method is FallbackChain
            if (method == Method::FallbackChain) {
                m_fallbackChain = {
                    Method::WebKit,
                    Method::MethodSwizzling,
                    Method::DynamicMessage
                };
            }
        }
        
        ExecutionIntegration::~ExecutionIntegration() {
            // Cleanup resources
            m_webKit = nullptr;
            m_methodSwizzling = nullptr;
            m_dynamicMessage = nullptr;
            m_loadstring = nullptr;
            
            std::cout << "ExecutionIntegration: Destroyed" << std::endl;
        }
        
        bool ExecutionIntegration::Initialize() {
            std::cout << "ExecutionIntegration: Initializing..." << std::endl;
            
            // If AutoSelect, determine best method first
            if (m_primaryMethod == Method::AutoSelect) {
                m_primaryMethod = DetermineBestMethod();
                std::cout << "ExecutionIntegration: Auto-selected method: " 
                          << MethodToString(m_primaryMethod) << std::endl;
            }
            
            // Initialize primary method
            bool success = InitializeMethod(m_primaryMethod);
            
            // Initialize fallback methods if using fallback chain
            if (m_primaryMethod == Method::FallbackChain) {
                for (const auto& method : m_fallbackChain) {
                    InitializeMethod(method);
                }
            }
            
            // Initialize loadstring support
            m_loadstring = std::make_shared<LoadstringSupport>();
            if (m_loadstring) {
                m_loadstring->Initialize();
            }
            
            std::cout << "ExecutionIntegration: Initialization " 
                      << (success ? "successful" : "failed") << std::endl;
                      
            return success;
        }
        
        bool ExecutionIntegration::InitializeMethod(Method method) {
            switch (method) {
                case Method::WebKit:
                    m_webKit = std::make_shared<WebKitExploit>();
                    return m_webKit->Initialize();
                    
                case Method::MethodSwizzling:
                    m_methodSwizzling = std::make_shared<MethodSwizzlingExploit>();
                    return m_methodSwizzling->Initialize();
                    
                case Method::DynamicMessage:
                    m_dynamicMessage = std::make_shared<DynamicMessageDispatcher>();
                    return m_dynamicMessage->Initialize();
                    
                case Method::AutoSelect:
                case Method::FallbackChain:
                    // These are handled separately
                    return true;
                    
                default:
                    return false;
            }
        }
        
        ExecutionIntegration::Method ExecutionIntegration::DetermineBestMethod() {
            // Try to initialize each method and test its availability
            std::shared_ptr<WebKitExploit> webKit = std::make_shared<WebKitExploit>();
            if (webKit->Initialize() && webKit->IsAvailable()) {
                return Method::WebKit;
            }
            
            std::shared_ptr<MethodSwizzlingExploit> methodSwizzling = std::make_shared<MethodSwizzlingExploit>();
            if (methodSwizzling->Initialize() && methodSwizzling->IsAvailable()) {
                return Method::MethodSwizzling;
            }
            
            std::shared_ptr<DynamicMessageDispatcher> dynamicMessage = std::make_shared<DynamicMessageDispatcher>();
            if (dynamicMessage->Initialize() && dynamicMessage->IsAvailable()) {
                return Method::DynamicMessage;
            }
            
            // If no method is available, use fallback chain
            return Method::FallbackChain;
        }
        
        ExecutionIntegration::ExecutionResult ExecutionIntegration::Execute(const std::string& script) {
            // Check for cached result
            auto it = m_scriptCache.find(script);
            if (it != m_scriptCache.end()) {
                ExecutionResult result(true, "", it->second, 0, "Cache");
                return result;
            }
            
            // Execute based on primary method
            if (m_primaryMethod == Method::FallbackChain) {
                // Try each method in the fallback chain
                for (const auto& method : m_fallbackChain) {
                    ExecutionResult result = ExecuteWithMethod(script, method);
                    if (result.m_success) {
                        // Cache successful result
                        m_scriptCache[script] = result.m_output;
                        return result;
                    }
                }
                
                // All methods failed
                return ExecutionResult(false, "All execution methods failed", "", 0, "FallbackChain");
            } else {
                // Execute with the primary method
                ExecutionResult result = ExecuteWithMethod(script, m_primaryMethod);
                
                // Cache successful result
                if (result.m_success) {
                    m_scriptCache[script] = result.m_output;
                }
                
                return result;
            }
        }
        
        ExecutionIntegration::ExecutionResult ExecutionIntegration::ExecuteWithMethod(
            const std::string& script, Method method) {
            
            uint64_t startTime = GetCurrentTimeMs();
            std::string output;
            bool success = false;
            std::string error;
            
            try {
                switch (method) {
                    case Method::WebKit:
                        if (m_webKit && m_webKit->IsAvailable()) {
                            output = m_webKit->ExecuteScript(script);
                            success = true;
                        } else {
                            error = "WebKit execution method not available";
                        }
                        break;
                        
                    case Method::MethodSwizzling:
                        if (m_methodSwizzling && m_methodSwizzling->IsAvailable()) {
                            output = m_methodSwizzling->ExecuteScript(script);
                            success = true;
                        } else {
                            error = "Method swizzling execution method not available";
                        }
                        break;
                        
                    case Method::DynamicMessage:
                        if (m_dynamicMessage && m_dynamicMessage->IsAvailable()) {
                            output = m_dynamicMessage->ExecuteScript(script);
                            success = true;
                        } else {
                            error = "Dynamic message execution method not available";
                        }
                        break;
                        
                    default:
                        error = "Invalid execution method";
                        break;
                }
            } catch (const std::exception& e) {
                error = "Exception during execution: " + std::string(e.what());
                success = false;
            }
            
            // Calculate execution time
            uint64_t executionTime = GetCurrentTimeMs() - startTime;
            
            // Process output if callback is set
            if (success && m_outputCallback) {
                ProcessOutput(output);
            }
            
            return ExecutionResult(success, error, output, executionTime, MethodToString(method));
        }
        
        ExecutionIntegration::ExecutionResult ExecutionIntegration::ExecuteWithLoadstring(
            const std::string& script, const std::string& chunkName) {
            
            // Check if loadstring is supported
            if (!m_loadstring || !m_loadstring->IsAvailable()) {
                return ExecutionResult(false, "Loadstring support not available", "", 0, "Loadstring");
            }
            
            // Inject loadstring support if not already injected
            if (!m_loadstringInjected) {
                Execute(m_loadstring->GetInjectionScript());
                m_loadstringInjected = true;
            }
            
            // Prepare the loadstring script
            std::string wrappedScript = m_loadstring->WrapScript(script, chunkName);
            
            // Execute the wrapped script
            return Execute(wrappedScript);
        }
        
        bool ExecutionIntegration::SetMethod(Method method) {
            // Cannot change to AutoSelect or FallbackChain after initialization
            if (m_webKit || m_methodSwizzling || m_dynamicMessage) {
                if (method == Method::AutoSelect || method == Method::FallbackChain) {
                    return false;
                }
            }
            
            // Set the new method
            m_primaryMethod = method;
            
            // Initialize the new method if needed
            if (!InitializeMethod(method)) {
                return false;
            }
            
            return true;
        }
        
        ExecutionIntegration::Method ExecutionIntegration::GetMethod() const {
            return m_primaryMethod;
        }
        
        void ExecutionIntegration::SetOutputCallback(const OutputCallback& callback) {
            m_outputCallback = callback;
        }
        
        void ExecutionIntegration::SetFallbackChain(const std::vector<Method>& methods) {
            m_fallbackChain = methods;
        }
        
        std::vector<ExecutionIntegration::Method> ExecutionIntegration::GetFallbackChain() const {
            return m_fallbackChain;
        }
        
        void ExecutionIntegration::ClearCache() {
            m_scriptCache.clear();
        }
        
        bool ExecutionIntegration::IsMethodAvailable(Method method) const {
            switch (method) {
                case Method::WebKit:
                    return m_webKit && m_webKit->IsAvailable();
                    
                case Method::MethodSwizzling:
                    return m_methodSwizzling && m_methodSwizzling->IsAvailable();
                    
                case Method::DynamicMessage:
                    return m_dynamicMessage && m_dynamicMessage->IsAvailable();
                    
                case Method::AutoSelect:
                case Method::FallbackChain:
                    // These are always available
                    return true;
                    
                default:
                    return false;
            }
        }
        
        std::vector<ExecutionIntegration::Method> ExecutionIntegration::GetAvailableMethods() const {
            std::vector<Method> availableMethods;
            
            if (IsMethodAvailable(Method::WebKit)) {
                availableMethods.push_back(Method::WebKit);
            }
            
            if (IsMethodAvailable(Method::MethodSwizzling)) {
                availableMethods.push_back(Method::MethodSwizzling);
            }
            
            if (IsMethodAvailable(Method::DynamicMessage)) {
                availableMethods.push_back(Method::DynamicMessage);
            }
            
            // AutoSelect and FallbackChain are always available
            availableMethods.push_back(Method::AutoSelect);
            availableMethods.push_back(Method::FallbackChain);
            
            return availableMethods;
        }
        
        std::string ExecutionIntegration::MethodToString(Method method) {
            switch (method) {
                case Method::WebKit:
                    return "WebKit";
                case Method::MethodSwizzling:
                    return "MethodSwizzling";
                case Method::DynamicMessage:
                    return "DynamicMessage";
                case Method::AutoSelect:
                    return "AutoSelect";
                case Method::FallbackChain:
                    return "FallbackChain";
                default:
                    return "Unknown";
            }
        }
        
        std::string ExecutionIntegration::GetMethodDescription(Method method) {
            switch (method) {
                case Method::WebKit:
                    return "Executes scripts using WebKit JavaScript engine";
                    
                case Method::MethodSwizzling:
                    return "Executes scripts using Objective-C method swizzling";
                    
                case Method::DynamicMessage:
                    return "Executes scripts using dynamic message dispatch";
                    
                case Method::AutoSelect:
                    return "Automatically selects the best available execution method";
                    
                case Method::FallbackChain:
                    return "Tries multiple execution methods in succession";
                    
                default:
                    return "Unknown execution method";
            }
        }
        
        void ExecutionIntegration::ProcessOutput(const std::string& output) {
            if (m_outputCallback) {
                m_outputCallback(output);
            }
        }
        
        std::string ExecutionIntegration::InjectLoadstringSupport(const std::string& script) {
            if (!m_loadstring) {
                return script;
            }
            
            return m_loadstring->InjectSupport(script);
        }

        // Helper function to integrate HTTP functions
        bool IntegrateHttpFunctions(std::shared_ptr<ExecutionIntegration> engine) {
            if (!engine) {
                return false;
            }
            
            // Set up HTTP functions wrapper script
            const std::string httpFunctionsScript = R"(
                -- HTTP functions wrapper
                local http = {}
                
                -- HTTP GET request
                function http.get(url, headers)
                    headers = headers or {}
                    -- Implementation goes here
                    return {
                        Success = true,
                        StatusCode = 200,
                        StatusMessage = "OK",
                        Headers = {},
                        Body = "HTTP GET simulation"
                    }
                end
                
                -- HTTP POST request
                function http.post(url, body, headers, contentType)
                    headers = headers or {}
                    contentType = contentType or "application/json"
                    -- Implementation goes here
                    return {
                        Success = true,
                        StatusCode = 200,
                        StatusMessage = "OK",
                        Headers = {},
                        Body = "HTTP POST simulation"
                    }
                end
                
                -- Make HTTP functions available globally
                _G.http = http
                
                return "HTTP functions integrated"
            )";
            
            // Execute the script to set up HTTP functions
            auto result = engine->Execute(httpFunctionsScript);
            
            std::cout << "HTTP Functions Integration: " 
                      << (result.m_success ? "Successful" : "Failed") << std::endl;
            
            return result.m_success;
        }
    }
}
