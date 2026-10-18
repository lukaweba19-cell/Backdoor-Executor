
#include "../../objc_isolation.h"
#pragma once

#include <string>
#include <vector>
#include <functional>
#include <unordered_map>
#include <memory>

namespace iOS {
namespace AdvancedBypass {

    /**
     * @class HttpClient
     * @brief Provides HTTP request capabilities for script loading
     * 
     * This class implements HTTP/HTTPS requests compatible with non-jailbroken
     * devices. It emulates Roblox's HttpGet functionality to allow scripts to
     * load directly from URLs using standard patterns.
     */
    class HttpClient {
    public:
        // HTTP request result structure
        struct RequestResult {
            bool m_success;              // Request succeeded
            int m_statusCode;            // HTTP status code
            std::string m_error;         // Error message if failed
            std::string m_content;       // Response content
            uint64_t m_requestTime;      // Request time in milliseconds
            
            RequestResult()
                : m_success(false), m_statusCode(0), m_requestTime(0) {}
                
            RequestResult(bool success, int statusCode, const std::string& error,
                         const std::string& content, uint64_t requestTime)
                : m_success(success), m_statusCode(statusCode), m_error(error),
                  m_content(content), m_requestTime(requestTime) {}
        };
        
        // Callback for request completion
        using CompletionCallback = std::function<void(const RequestResult&)>;
        
    private:
        // Member variables with consistent m_ prefix
        bool m_initialized;                 // Whether client is initialized
        int m_defaultTimeout;               // Default timeout in seconds
        bool m_useCache;                    // Whether to cache responses
        std::unordered_map<std::string, RequestResult> m_cache; // Response cache
        void* m_sessionConfig;              // Opaque pointer to NSURLSessionConfiguration
        void* m_session;                    // Opaque pointer to NSURLSession
        
        // Private methods
        void SendRequest(const std::string& url, const std::string& method, 
                        const std::unordered_map<std::string, std::string>& headers,
                        const std::string& body, int timeout, CompletionCallback callback);
        bool ValidateUrl(const std::string& url);
        std::string NormalizeUrl(const std::string& url) const;
        bool ShouldUseCache(const std::string& url, const std::string& method);
        void AddToCacheIfNeeded(const std::string& url, const RequestResult& result);
        RequestResult GetFromCacheIfAvailable(const std::string& url);
        
    public:
        /**
         * @brief Constructor
         * @param defaultTimeout Default timeout in seconds
         * @param useCache Whether to cache responses
         */
        HttpClient(int defaultTimeout = 30, bool useCache = true);
        
        /**
         * @brief Destructor
         */
        ~HttpClient();
        
        /**
         * @brief Initialize the HTTP client
         * @return True if initialization succeeded, false otherwise
         */
        bool Initialize();
        
        /**
         * @brief Synchronous HTTP GET request
         * @param url URL to request
         * @param timeout Timeout in seconds (0 for default)
         * @return Request result
         */
        RequestResult Get(const std::string& url, int timeout = 0);
        
        /**
         * @brief Asynchronous HTTP GET request
         * @param url URL to request
         * @param callback Callback function
         * @param timeout Timeout in seconds (0 for default)
         */
        void GetAsync(const std::string& url, CompletionCallback callback, int timeout = 0);
        
        /**
         * @brief Synchronous HTTP POST request
         * @param url URL to request
         * @param body Request body
         * @param timeout Timeout in seconds (0 for default)
         * @return Request result
         */
        RequestResult Post(const std::string& url, const std::string& body, int timeout = 0);
        
        /**
         * @brief Asynchronous HTTP POST request
         * @param url URL to request
         * @param body Request body
         * @param callback Callback function
         * @param timeout Timeout in seconds (0 for default)
         */
        void PostAsync(const std::string& url, const std::string& body, 
                      CompletionCallback callback, int timeout = 0);
        
        /**
         * @brief Set the default timeout
         * @param timeout Timeout in seconds
         */
        void SetDefaultTimeout(int timeout);
        
        /**
         * @brief Get the default timeout
         * @return Default timeout in seconds
         */
        int GetDefaultTimeout() const;
        
        /**
         * @brief Enable or disable response caching
         * @param useCache Whether to cache responses
         */
        void SetUseCache(bool useCache);
        
        /**
         * @brief Check if response caching is enabled
         * @return True if caching is enabled, false otherwise
         */
        bool GetUseCache() const;
        
        /**
         * @brief Clear the response cache
         */
        void ClearCache();
        
        /**
         * @brief Check if a URL is cached
         * @param url URL to check
         * @return True if cached, false otherwise
         */
        bool IsUrlCached(const std::string& url) const;
        
        /**
         * @brief Get Lua code for HTTP functions
         * @return Lua code implementing game:HttpGet and related functions
         */
        static std::string GetHttpFunctionsCode();
        
        /**
         * @brief Check if HTTP requests are available
         * @return True if available, false otherwise
         */
        static bool IsAvailable();
    };

} // namespace AdvancedBypass
} // namespace iOS
