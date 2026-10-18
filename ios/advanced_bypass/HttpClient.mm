#include "../../ios_compat.h"
#include "HttpClient.h"
#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <functional>
#include <chrono>
#include <thread>
#include <atomic>
#include <mutex>

#ifdef __APPLE__
#import <Foundation/Foundation.h>

namespace iOS {
namespace AdvancedBypass {

    // Constructor
    HttpClient::HttpClient(int defaultTimeout, bool useCache)
        : m_initialized(false),
          m_defaultTimeout(defaultTimeout),
          m_useCache(useCache),
          m_sessionConfig(nullptr),
          m_session(nullptr) {
    }
    
    // Destructor
    HttpClient::~HttpClient() {
        // Release NSURLSession and configuration with ARC-compatible bridging
        if (m_session) {
            // Use __bridge_transfer to transfer ownership from C++ to ARC
            NSURLSession* session = (__bridge_transfer NSURLSession*)m_session;
            m_session = nullptr;
            
            // No need to call release with ARC and __bridge_transfer
        }
        
        if (m_sessionConfig) {
            // Use __bridge_transfer to transfer ownership from C++ to ARC
            NSURLSessionConfiguration* config = (__bridge_transfer NSURLSessionConfiguration*)m_sessionConfig;
            m_sessionConfig = nullptr;
            
            // No need to call release with ARC and __bridge_transfer
        }
    }
    
    // Initialize the HTTP client
    bool HttpClient::Initialize() {
        // Check if already initialized
        if (m_initialized) {
            return true;
        }
        
        @try {
            // Create session configuration
            NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
            config.timeoutIntervalForRequest = m_defaultTimeout;
            config.timeoutIntervalForResource = m_defaultTimeout * 2;
            config.HTTPMaximumConnectionsPerHost = 5;
            
            // Setup cache policy based on settings
            config.requestCachePolicy = m_useCache ? 
                NSURLRequestReturnCacheDataElseLoad : 
                NSURLRequestReloadIgnoringLocalCacheData;
            
            // Set up headers to mimic a normal browser
            config.HTTPAdditionalHeaders = @{
                @"User-Agent": @"Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1",
                @"Accept": @"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                @"Accept-Language": @"en-US,en;q=0.9"
            };
            
            // Store configuration with ARC-compatible bridging
            m_sessionConfig = (__bridge_retained void*)config;
            
            // Create session with ARC-compatible bridging
            NSURLSession* session = [NSURLSession sessionWithConfiguration:config];
            m_session = (__bridge_retained void*)session;
            
            m_initialized = true;
            return true;
        }
        @catch (NSException* exception) {
            std::cerr << "HttpClient::Initialize failed: " << [[exception reason] UTF8String] << std::endl;
            return false;
        }
    }
    
    // Send HTTP request with all parameters (private method)
    void HttpClient::SendRequest(const std::string& url, 
                               const std::string& method, 
                               const std::unordered_map<std::string, std::string>& headers,
                               const std::string& body, 
                               int timeout,
                               CompletionCallback callback) {
        // Ensure initialized
        if (!m_initialized && !Initialize()) {
            RequestResult result(false, -1, "HTTP client failed to initialize", "", 0);
            callback(result);
            return;
        }
        
        // Get start time for performance tracking
        uint64_t startTime = std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::system_clock::now().time_since_epoch()).count();
        
        // Perform on background thread to avoid blocking
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), 
^
{
            @try {
                // Create URL
                NSString* urlString = [NSString stringWithUTF8String:url.c_str()];
                NSURL* nsUrl = [NSURL URLWithString:urlString];
                
                if (!nsUrl) {
                    RequestResult result(false, -1, "Invalid URL: " + url, "", 0);
                    dispatch_async(dispatch_get_main_queue(), 
^
{
                        callback(result);
                    });
                    return;
                }
                
                // Create request
                NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:nsUrl];
                
                // Set method
                [request setHTTPMethod:[NSString stringWithUTF8String:method.c_str()]];
                
                // Set timeout
                if (timeout > 0) {
                    [request setTimeoutInterval:timeout];
                }
                
                // Set headers
                for (const auto& header : headers) {
                    NSString* key = [NSString stringWithUTF8String:header.first.c_str()];
                    NSString* value = [NSString stringWithUTF8String:header.second.c_str()];
                    [request setValue:value forHTTPHeaderField:key];
                }
                
                // Set body if not empty
                if (!body.empty()) {
                    NSData* bodyData = [NSData dataWithBytes:body.c_str() length:body.length()];
                    [request setHTTPBody:bodyData];
                }
                
                // Get session using proper ARC bridging
                NSURLSession* session = (__bridge NSURLSession*)m_session;
                
                // Create data task
                NSURLSessionDataTask* task = [session dataTaskWithRequest:request
                                                       completionHandler:
^
(NSData* data, NSURLResponse* response, NSError* error) {
                    // Calculate request time
                    uint64_t endTime = std::chrono::duration_cast<std::chrono::milliseconds>(
                        std::chrono::system_clock::now().time_since_epoch()).count();
                    uint64_t requestTime = endTime - startTime;
                    
                    // Create result object with initial values
                    bool success = false;
                    int statusCode = 0;
                    std::string errorStr = "";
                    std::string content = "";
                    
                    if (error) {
                        // Handle error
                        success = false;
                        statusCode = (int)[error code];
                        errorStr = [[error localizedDescription] UTF8String];
                    } else {
                        // Handle success
                        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
                        success = (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300);
                        statusCode = (int)httpResponse.statusCode;
                        
                        // Get response data
                        if (data) {
                            // Convert data to string
                            content = std::string((const char*)[data bytes], [data length]);
                        }
                        
                        // We can't store the headers in the RequestResult since it doesn't have an m_headers field
                        // Just log a few important ones for debugging
                        if (m_useCache) {
                            NSDictionary* respHeaders = httpResponse.allHeaderFields;
                            NSString* contentType = respHeaders[@"Content-Type"];
                            NSString* cacheControl = respHeaders[@"Cache-Control"];
                            NSLog(@"Response headers - Content-Type: %@, Cache-Control: %@", contentType, cacheControl);
                        }
                    }
                    
                    // Create final result with all data
                    RequestResult result(success, statusCode, errorStr, content, requestTime);
                    
                    // Call callback on main thread
                    dispatch_async(dispatch_get_main_queue(), 
^
{
                        callback(result);
                    });
                }];
                
                // Start task
                [task resume];
            }
            @catch (NSException* exception) {
                RequestResult result(false, -1, [[exception reason] UTF8String], "", 0);
                
                dispatch_async(dispatch_get_main_queue(), 
^
{
                    callback(result);
                });
            }
        });
    }
    
    // Synchronous GET request implementation
    HttpClient::RequestResult HttpClient::Get(const std::string& url, int timeout) {
        // Create a semaphore for synchronous wait
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        // Response data
        RequestResult result;
        
        // Make async call but wait for completion
        GetAsync(url, [&result, &semaphore](const RequestResult& asyncResult) {
            result = asyncResult;
            dispatch_semaphore_signal(semaphore);
        }, timeout);
        
        // Wait for completion
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        
        return result;
    }
    
    // Asynchronous GET request
    void HttpClient::GetAsync(const std::string& url, CompletionCallback callback, int timeout) {
        SendRequest(url, "GET", {}, "", timeout > 0 ? timeout : m_defaultTimeout, callback);
    }
    
    // Synchronous POST request implementation
    HttpClient::RequestResult HttpClient::Post(const std::string& url, const std::string& body, int timeout) {
        // Create a semaphore for synchronous wait
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        // Response data
        RequestResult result;
        
        // Make async call but wait for completion
        PostAsync(url, body, [&result, &semaphore](const RequestResult& asyncResult) {
            result = asyncResult;
            dispatch_semaphore_signal(semaphore);
        }, timeout);
        
        // Wait for completion
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        
        return result;
    }
    
    // Asynchronous POST request
    void HttpClient::PostAsync(const std::string& url, const std::string& body, 
                           CompletionCallback callback, int timeout) {
        std::unordered_map<std::string, std::string> headers = {
            {"Content-Type", "application/x-www-form-urlencoded"}
        };
        SendRequest(url, "POST", headers, body, timeout > 0 ? timeout : m_defaultTimeout, callback);
    }
}
}
#endif // __APPLE__
