#include "ios_impl_compat.h"
#include "ExecutionEngine.h"
#include "LuaInterpreterIntegration.h"
#include "naming_conventions/script_preprocessor.h"
#include <iostream>
#include <chrono>
#include <thread>
#include <sstream>
#include <algorithm>
#include <random>
#include <iomanip>  // For std::setw and std::setfill

// Objective-C frameworks need to be imported at the top level

namespace iOS {
    // Constructor
    ExecutionEngine::ExecutionEngine(std::shared_ptr<ScriptManager> scriptManager)
        : m_scriptManager(scriptManager),
          m_outputCallback(nullptr),
          m_isExecuting(false),
          m_retryCount(0) {
        
        // Initialize default context
        m_defaultContext.m_isJailbroken = CheckJailbreakStatus();
    }
    
    // Initialize the execution engine
    bool ExecutionEngine::Initialize() {
        try {
            // Detect jailbreak status
            m_defaultContext.m_isJailbroken = CheckJailbreakStatus();
            
            // Create script manager if not provided
            if (!m_scriptManager) {
                m_scriptManager = std::make_shared<ScriptManager>();
                if (!m_scriptManager->Initialize()) {
                    std::cerr << "ExecutionEngine: Failed to initialize script manager" << std::endl;
                    return false;
                }
            }
            
            // Initialize default context based on device capabilities
            SetupBypassEnvironment(m_defaultContext);
            
            std::cout << "ExecutionEngine: Initialized for " 
                      << (m_defaultContext.m_isJailbroken ? "jailbroken" : "non-jailbroken") 
                      << " device" << std::endl;
            
            return true;
        } catch (const std::exception& e) {
            std::cerr << "ExecutionEngine: Exception during initialization: " << e.what() << std::endl;
            return false;
        }
    }
    
    // Execute a script
    ExecutionEngine::ExecutionResult ExecutionEngine::Execute(
        const std::string& script, const ExecutionContext& context) {
        
        // Check if already executing
        if (m_isExecuting) {
            return ExecutionResult(false, "Another script is already executing");
        }
        
        // Set executing flag
        std::lock_guard<std::mutex> lock(m_executionMutex);
        m_isExecuting = true;
        m_retryCount = 0;
        
        // Start timing
        auto startTime = std::chrono::high_resolution_clock::now();
        
        try {
            // Make a copy of the provided context (or use default if empty)
            ExecutionContext executionContext = context;
            
            // Call before-execute callbacks
            for (const auto& callback : m_beforeCallbacks) {
                if (!callback(script, executionContext)) {
                    // Callback returned false, abort execution
                    m_isExecuting = false;
                    return ExecutionResult(false, "Execution aborted by before-execute callback");
                }
            }
            
            // Prepare the script for execution
            std::string preparedScript = PrepareScript(script, executionContext);
            
            // Execute script based on available methods
            
            // Variables to build the execution result - using __block to allow modification in blocks
            __block std::string resultOutput;
            __block bool resultSuccess = false;
            __block std::string resultError;
            
            // Jailbreak required — WebKit non-JB path removed
            if (!executionContext.m_isJailbroken) {
                resultSuccess = false;
                resultError = "Script execution requires a jailbroken device. Non-jailbroken WebKit execution has been removed.";
            } else {
                // Jailbroken path: execute via embedded Luau interpreter
                auto& lua = LuaInterpreterIntegration::GetInstance();
                if (!lua.IsInitialized()) {
                    if (!lua.Initialize()) {
                        resultSuccess = false;
                        resultError = "Failed to initialize Lua interpreter for jailbroken execution";
                    }
                }
                if (resultError.empty()) {
                    LuaInterpreterIntegration::ExecutionOptions opts;
                    opts.useSandbox = executionContext.m_enableAntiDetection;
                    opts.captureOutput = true;
                    opts.usePreprocessor = true;
                    auto luaResult = lua.ExecuteScript(script, opts);
                    resultSuccess = luaResult.success;
                    resultOutput = luaResult.output;
                    if (!luaResult.success) {
                        resultError = luaResult.error.empty()
                            ? "Lua execution failed" : luaResult.error;
                    }
                    for (const auto& rv : luaResult.returnValues) {
                        if (!resultOutput.empty()) resultOutput += "\n";
                        resultOutput += rv;
                    }
                }
            }

            // Process output
            if (m_outputCallback && !resultOutput.empty()) {
                m_outputCallback(resultOutput);
            }
            
            // Calculate execution time
            auto endTime = std::chrono::high_resolution_clock::now();
            uint64_t executionTime = std::chrono::duration_cast<std::chrono::milliseconds>(endTime - startTime).count();
            
            // Create result
            ExecutionResult result(resultSuccess, resultError, executionTime, resultOutput);
            
            // Call after-execute callbacks
            for (const auto& callback : m_afterCallbacks) {
                callback(script, result);
            }
            
            // Log execution
            LogExecution(script, result);
            
            // Reset executing flag
            m_isExecuting = false;
            
            // Handle auto-retry if enabled and execution failed
            if (!resultSuccess && executionContext.m_autoRetry && m_retryCount < executionContext.m_maxRetries) {
                m_retryCount++;
                std::cout << "ExecutionEngine: Auto-retrying script execution (attempt " << m_retryCount 
                          << " of " << executionContext.m_maxRetries << ")" << std::endl;
                
                // Wait a bit before retrying
                std::this_thread::sleep_for(std::chrono::milliseconds(500 * m_retryCount));
                
                // Retry execution
                return Execute(script, executionContext);
            }
            
            return result;
        } catch (const std::exception& e) {
            // Handle exceptions
            std::cerr << "ExecutionEngine: Exception during execution: " << e.what() << std::endl;
            
            // Reset executing flag
            m_isExecuting = false;
            
            // Calculate execution time
            auto endTime = std::chrono::high_resolution_clock::now();
            uint64_t executionTime = std::chrono::duration_cast<std::chrono::milliseconds>(endTime - startTime).count();
            
            return ExecutionResult(false, std::string("Exception: ") + e.what(), executionTime);
        }
    }
    
    // Execute a script by name from the script manager
    ExecutionEngine::ExecutionResult ExecutionEngine::ExecuteByName(
        const std::string& scriptName, const ExecutionContext& context) {
        
        // Check if script manager is available
        if (!m_scriptManager) {
            return ExecutionResult(false, "Script manager not available");
        }
        
        // Get the script
        ScriptManager::Script script = m_scriptManager->GetScript(scriptName);
        if (script.m_name.empty()) {
            return ExecutionResult(false, "Script not found: " + scriptName);
        }
        
        // Execute the script
        return Execute(script.m_content, context);
    }
    
    // Set the default execution context
    void ExecutionEngine::SetDefaultContext(const ExecutionContext& context) {
        m_defaultContext = context;
    }
    
    // Get the default execution context
    ExecutionEngine::ExecutionContext ExecutionEngine::GetDefaultContext() const {
        return m_defaultContext;
    }
    
    // Register a callback to be called before script execution
    void ExecutionEngine::RegisterBeforeExecuteCallback(const BeforeExecuteCallback& callback) {
        if (callback) {
            m_beforeCallbacks.push_back(callback);
        }
    }
    
    // Register a callback to be called after script execution
    void ExecutionEngine::RegisterAfterExecuteCallback(const AfterExecuteCallback& callback) {
        if (callback) {
            m_afterCallbacks.push_back(callback);
        }
    }
    
    // Set the output callback function
    void ExecutionEngine::SetOutputCallback(const OutputCallback& callback) {
        m_outputCallback = callback;
    }
    
    // Check if the engine is currently executing a script
    bool ExecutionEngine::IsExecuting() const {
        return m_isExecuting;
    }
    
    // Set the script manager
    void ExecutionEngine::SetScriptManager(std::shared_ptr<ScriptManager> scriptManager) {
        m_scriptManager = scriptManager;
    }
    
    // Detect if device is jailbroken
    bool ExecutionEngine::IsJailbroken() {
        // Check common jailbreak indicators
        
        // 1. Check for common jailbreak files
        NSArray* jailbreakFiles = @[
            @"/Applications/Cydia.app",
            @"/Library/MobileSubstrate/MobileSubstrate.dylib",
            @"/bin/bash",
            @"/usr/sbin/sshd",
            @"/etc/apt",
            @"/private/var/lib/apt"
        ];
        
        for (NSString* path in jailbreakFiles) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
                return true;
            }
        }
        
        // 2. Check if we can write to a system location
        NSError* error;
        NSString* testPath = @"/private/jailbreak_test";
        NSString* testString = @"Jailbreak test";
        
        BOOL written = [testString writeToFile:testPath 
                                    atomically:YES 
                                      encoding:NSUTF8StringEncoding 
                                         error:&error];
        
        if (written) {
            // Clean up the test file
            [[NSFileManager defaultManager] removeItemAtPath:testPath error:nil];
            return true;
        }
        
        // 3. Check for URL schemes
        if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"cydia://"]]) {
            return true;
        }
        
        return false;
    }
    
    // Check jailbreak status
    bool ExecutionEngine::CheckJailbreakStatus() {
        return IsJailbroken();
    }
    
    // Obfuscate a script
    std::string ExecutionEngine::ObfuscateScript(const std::string& script) {
        // In a real implementation, you'd use proper obfuscation techniques
        // This is a simple demonstration
        
        // Generate a random key
        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_int_distribution<> dist(1, 255);
        int key = dist(gen);
        
        // Create the obfuscated script
        std::stringstream obfuscated;
        
        // Add a decoding function
        obfuscated << "local function _d(s,k)\n";
        obfuscated << "    local r=''\n";
        obfuscated << "    for i=1,#s do\n";
        obfuscated << "        local c=string.byte(s,i)\n";
        obfuscated << "        r=r..string.char(c~k)\n";
        obfuscated << "    end\n";
        obfuscated << "    return r\n";
        obfuscated << "end\n\n";
        
        // Encrypt the script with XOR
        std::string encrypted;
        for (char c : script) {
            encrypted += static_cast<char>(c ^ key);
        }
        
        // Convert to hex for string literal
        std::stringstream hexStream;
        hexStream << "local _s='";
        for (char c : encrypted) {
            hexStream << std::hex << std::setw(2) << std::setfill('0') << (int)(unsigned char)c;
        }
        hexStream << "'\n";
        
        obfuscated << hexStream.str();
        
        // Add decoding and execution code
        obfuscated << "local _h=''\n";
        obfuscated << "for i=1,#_s,2 do\n";
        obfuscated << "    _h=_h..string.char(tonumber(_s:sub(i,i+1),16))\n";
        obfuscated << "end\n\n";
        obfuscated << "local _decoded=_d(_h," << key << ")\n";
        obfuscated << "local _f=loadstring or load\n";
        obfuscated << "return _f(_decoded)()\n";
        
        return obfuscated.str();
    }
    
    // Apply naming conventions to a script
    std::string ExecutionEngine::ApplyNamingConventions(const std::string& script) {
        // Use the script preprocessor to apply naming conventions
        auto& preprocessor = RobloxExecutor::NamingConventions::ScriptPreprocessor::GetInstance();
        
        // Make sure the preprocessor is initialized
        if (!preprocessor.Initialize()) {
            std::cerr << "ExecutionEngine: Failed to initialize script preprocessor" << std::endl;
            return script;
        }
        
        // Preprocess the script
        return preprocessor.PreprocessScript(script);
    }
    
    // Prepare a script for execution
    std::string ExecutionEngine::PrepareScript(const std::string& script, const ExecutionContext& context) {
        // Apply various preparation steps based on context settings
        
        std::string preparedScript = script;
        
        // Add environment variables
        std::string envScript = GenerateExecutionEnvironment(context);
        preparedScript = envScript + "\n" + preparedScript;
        
        // Apply naming conventions if enabled
        if (context.m_enableNamingConventions) {
            preparedScript = ApplyNamingConventions(preparedScript);
        }
        
        // Apply obfuscation if enabled
        if (context.m_enableObfuscation) {
            preparedScript = ObfuscateScript(preparedScript);
        }
        
        return preparedScript;
    }
    
    // Process output from script execution
    void ExecutionEngine::ProcessOutput(const std::string& output) {
        if (m_outputCallback && !output.empty()) {
            m_outputCallback(output);
        }
    }
    
    // Setup the bypass environment based on device capabilities
    bool ExecutionEngine::SetupBypassEnvironment(const ExecutionContext& context) {
        if (!context.m_isJailbroken) {
            std::cout << "ExecutionEngine: Bypass environment requires jailbreak (non-JB WebKit path removed)" << std::endl;
            return false;
        }
        std::cout << "ExecutionEngine: Setting up jailbroken bypass environment" << std::endl;
        return true;
    }
    
    // Log script execution
    void ExecutionEngine::LogExecution(const std::string& script, const ExecutionResult& result) {
        // Create a log entry
        std::stringstream logEntry;
        logEntry << "======== Script Execution (" << (result.m_success ? "SUCCESS" : "FAILED") << ") ========\n";
        logEntry << "Time: " << result.m_executionTime << " ms\n";
        
        if (!result.m_error.empty()) {
            logEntry << "Error: " << result.m_error << "\n";
        }
        
        if (!result.m_output.empty()) {
            logEntry << "Output:\n" << result.m_output << "\n";
        }
        
        logEntry << "=================================================\n";
        
        // Write to log file if FileSystem is available
        if (!FileUtils::GetLogPath().empty()) {
            // Use direct path construction instead of private CombinePaths method
            std::string logPath = FileUtils::GetLogPath() + 
                                  "/execution_" + std::to_string(time(nullptr)) + ".log";
            
            FileUtils::WriteFile(logPath, logEntry.str());
        }
        
        // Output to console
        std::cout << logEntry.str() << std::endl;
    }
    
    // Generate execution environment with variables and helper functions
    std::string ExecutionEngine::GenerateExecutionEnvironment(const ExecutionContext& context) {
        std::stringstream env;
        
        // Add environment setup code
        env << "-- Environment setup for Executor\n";
        
        // Add game information
        env << "local _gameName = \"" << context.m_gameName << "\"\n";
        env << "local _placeId = \"" << context.m_placeId << "\"\n";
        
        // Add custom environment variables
        for (const auto& pair : context.m_environment) {
            env << "local " << pair.first << " = \"" << pair.second << "\"\n";
        }
        
        // Add helper functions for bypass
        env << "local function _getGameName() return _gameName end\n";
        env << "local function _getPlaceId() return _placeId end\n";
        
        // Wrap the script in a protected call for error handling
        env << "local function _logError(err)\n";
        env << "    print(\"Execution error: \" .. tostring(err))\n";
        env << "end\n\n";
        
        return env.str();
    }
    
    // Get available bypass methods
    std::vector<std::string> ExecutionEngine::GetAvailableBypassMethods() const {
        std::vector<std::string> methods;
        
        // Common methods available on all devices
        methods.push_back("BasicBypass");
        methods.push_back("ScriptObfuscation");
        
        // Methods available only on jailbroken devices
        if (m_defaultContext.m_isJailbroken) {
            methods.push_back("MemoryPatching");
            methods.push_back("FunctionHooking");
            methods.push_back("KernelBypass");
        }
        
        return methods;
    }
    
    // Check if a specific bypass method is available
    bool ExecutionEngine::IsMethodAvailable(const std::string& methodName) const {
        // Get all available methods
        std::vector<std::string> methods = GetAvailableBypassMethods();
        
        // Check if the specified method is in the list
        return std::find(methods.begin(), methods.end(), methodName) != methods.end();
    }
}
