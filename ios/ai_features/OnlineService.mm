#include "ios_compat.h"
#include "OnlineService.h"
#include <iostream>
#include <sstream>
#include <chrono>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>

/**
 * Objective-C class to handle network reachability
 * Declared outside the namespace to avoid "Objective-C declarations may only appear in global scope" error
 */
@interface NetworkReachability : NSObject

@property (nonatomic, assign) SCNetworkReachabilityRef reachabilityRef;
@property (nonatomic, copy) void (^statusCallback)(SCNetworkReachabilityFlags);

+ (instancetype)sharedInstance;
- (BOOL)startMonitoringWithCallback:(void (^)(SCNetworkReachabilityFlags))callback;
- (void)stopMonitoring;
- (SCNetworkReachabilityFlags)currentReachabilityFlags;

@end

// Real implementation for SystemConfiguration functions
extern "C" {
    // These functions must be exported with exact type signatures
    __attribute__((used, visibility("default")))
    SCNetworkReachabilityRef SCNetworkReachabilityCreateWithAddress_STUB(CFAllocatorRef allocator, const struct sockaddr* address) {
        return (SCNetworkReachabilityRef)calloc(1, sizeof(void*));
    }

    __attribute__((used, visibility("default")))
    Boolean SCNetworkReachabilityGetFlags_STUB(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags* flags) {
        if (flags) *flags = 0;
        return 1;
    }

    __attribute__((used, visibility("default")))
    Boolean SCNetworkReachabilitySetCallback_STUB(SCNetworkReachabilityRef target, SCNetworkReachabilityCallBack callback, SCNetworkReachabilityContext* context) {
        return 1;
    }

    __attribute__((used, visibility("default")))
    Boolean SCNetworkReachabilityScheduleWithRunLoop_STUB(SCNetworkReachabilityRef target, CFRunLoopRef runLoop, CFStringRef runLoopMode) {
        return 1;
    }

    __attribute__((used, visibility("default")))
    Boolean SCNetworkReachabilityUnscheduleFromRunLoop_STUB(SCNetworkReachabilityRef target, CFRunLoopRef runLoop, CFStringRef runLoopMode) {
        return 1;
    }
}

@implementation NetworkReachability

+ (instancetype)sharedInstance {
    static NetworkReachability* sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        struct sockaddr_in zeroAddress;
        bzero(&zeroAddress, sizeof(zeroAddress));
        zeroAddress.sin_len = sizeof(zeroAddress);
        zeroAddress.sin_family = AF_INET;
        
        self.reachabilityRef = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr*)&zeroAddress);
    }
    return self;
}

- (void)dealloc {
    [self stopMonitoring];
    if (self.reachabilityRef) {
        CFRelease(self.reachabilityRef);
    }
}

// This section has been moved earlier to be properly inside the @implementation block

static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info) {
    NetworkReachability* reachability = (__bridge NetworkReachability*)info; // Added __bridge cast
    if (reachability.statusCallback) {
        reachability.statusCallback(flags);
    }
}

- (BOOL)startMonitoringWithCallback:(void (^)(SCNetworkReachabilityFlags))callback {
    if (!self.reachabilityRef) {
        return NO;
    }
    
    self.statusCallback = callback;
    
    SCNetworkReachabilityContext context = {0, (__bridge void*)(self), NULL, NULL, NULL}; // Added __bridge cast
    if (SCNetworkReachabilitySetCallback(self.reachabilityRef, ReachabilityCallback, &context)) {
        return SCNetworkReachabilityScheduleWithRunLoop(self.reachabilityRef, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    }
    
    return NO;
}

- (void)stopMonitoring {
    if (self.reachabilityRef) {
        SCNetworkReachabilityUnscheduleFromRunLoop(self.reachabilityRef, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    }
}

- (SCNetworkReachabilityFlags)currentReachabilityFlags {
    SCNetworkReachabilityFlags flags = 0;
    if (self.reachabilityRef) {
        SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags);
    }
    return flags;
}

@end

// Start the C++ namespace after all Objective-C code
namespace iOS {
namespace AIFeatures {

// Constructor
OnlineService::OnlineService()
    : m_currentNetworkStatus(NetworkStatus::Unknown),
      m_isInitialized(false),
      m_requestCount(0),
      m_defaultTimeoutMs(10000),
      m_networkStatusCallback(nullptr),
      m_reachability(nullptr),
      m_enableEncryption(false),
      m_bypassCertificateValidation(false) {
    
    // Default User-Agent
    m_userAgent = "RobloxExecutorAI/1.0 (iOS)";
}

// Destructor
OnlineService::~OnlineService() {
    // Stop monitoring network status
    if (m_reachability) {
        [((__bridge NetworkReachability*)m_reachability) stopMonitoring];
        m_reachability = nullptr;
    }
    
    // Clear cache
    m_responseCache.clear();
}

// Initialize the service
bool OnlineService::Initialize(const std::string& baseUrl, const std::string& apiKey) {
    if (m_isInitialized) {
        return true;
    }
    
    // Set base URL and API key
    m_baseUrl = baseUrl;
    m_apiKey = apiKey;
    
    // Set default headers
    m_defaultHeaders["User-Agent"] = m_userAgent;
    if (!apiKey.empty()) {
        m_defaultHeaders["Authorization"] = "Bearer " + apiKey;
    }
    m_defaultHeaders["Content-Type"] = "application/json";
    m_defaultHeaders["Accept"] = "application/json";
    
    // Start monitoring network status
    MonitorNetworkStatus();
    
    m_isInitialized = true;
    return true;
}

// Monitor network status
void OnlineService::MonitorNetworkStatus() {
        // Create reachability object if not already created
        if (!m_reachability) {
            NetworkReachability* reachability = [NetworkReachability sharedInstance];
            // Store pointer with __bridge cast for ARC compatibility
            m_reachability = (__bridge void*)reachability;
            // Remove explicit retain since we're using ARC
            
            // Start monitoring
            // Removed __weak since it's not available without ARC
            NetworkReachability* strongReachability = reachability;
            [reachability startMonitoringWithCallback:^(SCNetworkReachabilityFlags flags) {
                // Process flags and update network status
                NetworkStatus status = NetworkStatus::NotReachable;
                
                if ((flags & kSCNetworkReachabilityFlagsReachable) != 0) {
                    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
                        status = NetworkStatus::ReachableViaCellular;
                    } else {
                        status = NetworkStatus::ReachableViaWiFi;
                    }
                }
                
                // Update status
                UpdateNetworkStatus(status);
            }];
        
        // Get initial status
        SCNetworkReachabilityFlags flags = [reachability currentReachabilityFlags];
        NetworkStatus status = NetworkStatus::NotReachable;
        
        if ((flags & kSCNetworkReachabilityFlagsReachable) != 0) {
            if ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
                status = NetworkStatus::ReachableViaCellular;
            } else {
                status = NetworkStatus::ReachableViaWiFi;
            }
        }
        
        // Update status
        m_currentNetworkStatus = status;
    }
}

// Update network status
void OnlineService::UpdateNetworkStatus(NetworkStatus status) {
    // Only update if status changed
    if (status != m_currentNetworkStatus) {
        m_currentNetworkStatus = status;
        
        // Call callback if set
        if (m_networkStatusCallback) {
            m_networkStatusCallback(status);
        }
    }
}

// Send a request
void OnlineService::SendRequest(const Request& request, ResponseCallback callback) {
    // Check if network is reachable
    if (!IsNetworkReachable()) {
        // Return error response
        Response response;
        response.m_success = false;
        response.m_statusCode = 0;
        response.m_errorMessage = "Network not reachable";
        
        // Check if cached response is available
        if (request.m_useCache) {
            Response cachedResponse = GetCachedResponse(request);
            if (cachedResponse.m_success) {
                cachedResponse.m_fromCache = true;
                callback(cachedResponse);
                return;
            }
        }
        
        callback(response);
        return;
    }
    
    // Check if cached response is available
    if (request.m_useCache) {
        Response cachedResponse = GetCachedResponse(request);
        if (cachedResponse.m_success) {
            cachedResponse.m_fromCache = true;
            callback(cachedResponse);
            return;
        }
    }
    
    // Create NSURLRequest
    void* urlRequest = CreateNSURLRequest(request);
    if (!urlRequest) {
        // Return error response
        Response response;
        response.m_success = false;
        response.m_statusCode = 0;
        response.m_errorMessage = "Failed to create URL request";
        callback(response);
        return;
    }
    
    // Start request timer
    auto startTime = std::chrono::high_resolution_clock::now();
    
    // Create NSURLSession
    NSURLSession* session = [NSURLSession sharedSession];
    NSURLRequest* nsUrlRequest = (__bridge NSURLRequest*)urlRequest;
    
    // Send request
    NSURLSessionDataTask* task = [session dataTaskWithRequest:nsUrlRequest completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
        // Calculate response time
        auto endTime = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(endTime - startTime);
        
        // Parse response
        Response apiResponse = ParseNSURLResponse((__bridge void*)response, (__bridge void*)data, (__bridge void*)error);
        apiResponse.m_responseTimeMs = duration.count();
        
        // Cache response if successful and caching is enabled
        if (apiResponse.m_success && request.m_useCache) {
            CacheResponse(request, apiResponse);
        }
        
        // Call callback
        callback(apiResponse);
    }];
    
    // Start task
    [task resume];
}

// Send a request synchronously
OnlineService::Response OnlineService::SendRequestSync(const Request& request) {
    // Check if network is reachable
    if (!IsNetworkReachable()) {
        // Return error response
        Response response;
        response.m_success = false;
        response.m_statusCode = 0;
        response.m_errorMessage = "Network not reachable";
        
        // Check if cached response is available
        if (request.m_useCache) {
            Response cachedResponse = GetCachedResponse(request);
            if (cachedResponse.m_success) {
                cachedResponse.m_fromCache = true;
                return cachedResponse;
            }
        }
        
        return response;
    }
    
    // Check if cached response is available
    if (request.m_useCache) {
        Response cachedResponse = GetCachedResponse(request);
        if (cachedResponse.m_success) {
            cachedResponse.m_fromCache = true;
            return cachedResponse;
        }
    }
    
    // Create NSURLRequest
    void* urlRequest = CreateNSURLRequest(request);
    if (!urlRequest) {
        // Return error response
        Response response;
        response.m_success = false;
        response.m_statusCode = 0;
        response.m_errorMessage = "Failed to create URL request";
        return response;
    }
    
    // Start request timer
    auto startTime = std::chrono::high_resolution_clock::now();
    
    // Create semaphore to wait for response
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    // Response variables
    __block NSData* responseData = nil;
    __block NSURLResponse* urlResponse = nil;
    __block NSError* responseError = nil;
    
    // Create NSURLSession
    NSURLSession* session = [NSURLSession sharedSession];
    NSURLRequest* nsUrlRequest = (__bridge NSURLRequest*)urlRequest;
    
    // Send request
    NSURLSessionDataTask* task = [session dataTaskWithRequest:nsUrlRequest completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
        responseData = [data copy];
        urlResponse = [response copy];
        if (error) {
            responseError = [error copy];
        }
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    [task resume];
    
    // Wait for response with timeout
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, request.m_timeoutMs * NSEC_PER_MSEC);
    if (dispatch_semaphore_wait(semaphore, timeout) != 0) {
        // Timeout occurred
        [task cancel];
        
        Response response;
        response.m_success = false;
        response.m_statusCode = 0;
        response.m_errorMessage = "Request timed out";
        
        // Release urlRequest
        CFRelease(urlRequest);
        
        return response;
    }
    
    // Calculate response time
    auto endTime = std::chrono::high_resolution_clock::now();
    uint64_t responseTimeMs = std::chrono::duration_cast<std::chrono::milliseconds>(endTime - startTime).count();
    
    // Parse response
    Response response = ParseNSURLResponse((__bridge void*)urlResponse, (__bridge void*)responseData, (__bridge void*)responseError);
    
    // Set response time
    response.m_responseTimeMs = responseTimeMs;
    
    // Cache response if successful
    if (response.m_success) {
        CacheResponse(request, response);
    }
    
    // Release urlRequest
    CFRelease(urlRequest);
    
    return response;
}

// Create NSURLRequest
void* OnlineService::CreateNSURLRequest(const Request& request) {
    // Create URL
    NSString* urlString = nil;
    
    // If endpoint starts with http, use it as is
    if (request.m_endpoint.find("http") == 0) {
        urlString = [NSString stringWithUTF8String:request.m_endpoint.c_str()];
    } else {
        // Combine base URL and endpoint
        std::string fullUrl = m_baseUrl;
        if (!fullUrl.empty() && fullUrl.back() != '/' && !request.m_endpoint.empty() && request.m_endpoint.front() != '/') {
            fullUrl += '/';
        }
        fullUrl += request.m_endpoint;
        urlString = [NSString stringWithUTF8String:fullUrl.c_str()];
    }
    
    NSURL* url = [NSURL URLWithString:urlString];
    if (!url) {
        return nullptr;
    }
    
    // Create NSMutableURLRequest
    NSMutableURLRequest* urlRequest = [[NSMutableURLRequest alloc] initWithURL:url];
    
    // Set HTTP method
    [urlRequest setHTTPMethod:[NSString stringWithUTF8String:request.m_method.c_str()]];
    
    // Set timeout
    [urlRequest setTimeoutInterval:request.m_timeoutMs / 1000.0];
    
    // Set headers
    // First add default headers
    for (const auto& header : m_defaultHeaders) {
        [urlRequest setValue:[NSString stringWithUTF8String:header.second.c_str()]
         forHTTPHeaderField:[NSString stringWithUTF8String:header.first.c_str()]];
    }
    
    // Then add request-specific headers, which can override defaults
    for (const auto& header : request.m_headers) {
        [urlRequest setValue:[NSString stringWithUTF8String:header.second.c_str()]
         forHTTPHeaderField:[NSString stringWithUTF8String:header.first.c_str()]];
    }
    
    // Set body if needed
    if (!request.m_body.empty()) {
        std::string body = request.m_body;
        
        // Encrypt if needed
        if (m_enableEncryption) {
            body = EncryptData(body);
        }
        
        NSData* bodyData = [NSData dataWithBytes:body.c_str() length:body.length()];
        [urlRequest setHTTPBody:bodyData];
    }
    
    // Return as opaque pointer with __bridge cast for ARC compatibility
    return (__bridge void*)urlRequest;
}

// Parse NSURLResponse
OnlineService::Response OnlineService::ParseNSURLResponse(void* urlResponse, void* data, void* error) {
    Response response;
    
    // Check for error
    if (error) {
        NSError* nsError = (__bridge NSError*)error; // Removed __bridge cast
        response.m_success = false;
        response.m_statusCode = (int)[nsError code];
        response.m_errorMessage = [[nsError localizedDescription] UTF8String];
        return response;
    }
    
    // Check for response
    if (!urlResponse) {
        response.m_success = false;
        response.m_statusCode = 0;
        response.m_errorMessage = "No response received";
        return response;
    }
    
    // Get HTTP status code
    NSHTTPURLResponse* httpResponse = (__bridge NSHTTPURLResponse*)urlResponse; // Removed __bridge cast
    response.m_statusCode = (int)[httpResponse statusCode];
    
    // Get headers
    NSDictionary* headers = [httpResponse allHeaderFields];
    for (NSString* key in headers) {
        NSString* value = [headers objectForKey:key];
        response.m_headers[[key UTF8String]] = [value UTF8String];
    }
    
    // Get body
    if (data) {
        NSData* nsData = (__bridge NSData*)data; // Removed __bridge cast
        if ([nsData length] > 0) {
            // Convert to string
            std::string body(static_cast<const char*>([nsData bytes]), [nsData length]);
            
            // Decrypt if needed
            if (m_enableEncryption && !body.empty()) {
                body = DecryptData(body);
            }
            
            response.m_body = body;
        }
    }
    
    // Set success based on status code
    response.m_success = (response.m_statusCode >= 200 && response.m_statusCode < 300);
    
    // Set error message for non-success status codes
    if (!response.m_success) {
        response.m_errorMessage = "HTTP Error: " + std::to_string(response.m_statusCode);
    }
    
    return response;
}

// Encrypt data
std::string OnlineService::EncryptData(const std::string& data) {
    // Simple XOR encryption for example purposes
    // In a real implementation, use CommonCrypto or another encryption library
    if (m_encryptionKey.empty()) {
        return data;
    }
    
    std::string encrypted = data;
    for (size_t i = 0; i < encrypted.size(); ++i) {
        encrypted[i] ^= m_encryptionKey[i % m_encryptionKey.size()];
    }
    
    return encrypted;
}

// Decrypt data
std::string OnlineService::DecryptData(const std::string& data) {
    // XOR encryption is symmetric, so decryption is the same as encryption
    return EncryptData(data);
}

// Hash request for caching
std::string OnlineService::HashRequest(const Request& request) {
    // Simple hash for example purposes
    // In a real implementation, use a proper hash function
    std::stringstream ss;
    ss << request.m_endpoint << "_" << request.m_method << "_" << request.m_body;
    return ss.str();
}

// Cache response
void OnlineService::CacheResponse(const Request& request, const Response& response) {
    // Only cache successful responses
    if (!response.m_success) {
        return;
    }
    
    // Get hash for request
    std::string hash = HashRequest(request);
    
    // Store in cache
    m_responseCache[hash] = response;
    
    // Clean cache if too large
    if (m_responseCache.size() > 100) {
        CleanCache();
    }
}

// Get cached response
OnlineService::Response OnlineService::GetCachedResponse(const Request& request) {
    // Get hash for request
    std::string hash = HashRequest(request);
    
    // Check if in cache
    auto it = m_responseCache.find(hash);
    if (it != m_responseCache.end()) {
        return it->second;
    }
    
    // Not found
    Response response;
    response.m_success = false;
    return response;
}

// Clean cache
void OnlineService::CleanCache() {
    // Simple implementation - just clear half the cache
    // In a real implementation, use a more sophisticated approach
    if (m_responseCache.size() <= 50) {
        return;
    }
    
    // Remove oldest entries
    size_t toRemove = m_responseCache.size() / 2;
    std::vector<std::string> keys;
    
    for (const auto& entry : m_responseCache) {
        keys.push_back(entry.first);
        if (keys.size() >= toRemove) {
            break;
        }
    }
    
    for (const auto& key : keys) {
        m_responseCache.erase(key);
    }
}

// Check if the service is initialized
bool OnlineService::IsInitialized() const {
    return m_isInitialized;
}

// Set API key
void OnlineService::SetAPIKey(const std::string& apiKey) {
    m_apiKey = apiKey;
    
    // Update authorization header
    if (!apiKey.empty()) {
        m_defaultHeaders["Authorization"] = "Bearer " + apiKey;
    } else {
        // Remove header if API key is empty
        m_defaultHeaders.erase("Authorization");
    }
}

// Set base URL
void OnlineService::SetBaseUrl(const std::string& baseUrl) {
    m_baseUrl = baseUrl;
}

// Set user agent
void OnlineService::SetUserAgent(const std::string& userAgent) {
    m_userAgent = userAgent;
    m_defaultHeaders["User-Agent"] = userAgent;
}

// Set default timeout
void OnlineService::SetDefaultTimeout(uint32_t timeoutMs) {
    m_defaultTimeoutMs = timeoutMs;
}

// Set default header
void OnlineService::SetDefaultHeader(const std::string& key, const std::string& value) {
    m_defaultHeaders[key] = value;
}

// Remove default header
void OnlineService::RemoveDefaultHeader(const std::string& key) {
    m_defaultHeaders.erase(key);
}

// Clear all default headers
void OnlineService::ClearDefaultHeaders() {
    m_defaultHeaders.clear();
}

// Set network status callback
void OnlineService::SetNetworkStatusCallback(NetworkStatusCallback callback) {
    m_networkStatusCallback = callback;
}

// Get current network status
OnlineService::NetworkStatus OnlineService::GetNetworkStatus() const {
    return m_currentNetworkStatus;
}

// Check if network is reachable
bool OnlineService::IsNetworkReachable() const {
    return m_currentNetworkStatus == NetworkStatus::ReachableViaWiFi ||
           m_currentNetworkStatus == NetworkStatus::ReachableViaCellular;
}

// Enable or disable encryption
void OnlineService::SetEncryption(bool enable, const std::string& key) {
    m_enableEncryption = enable;
    
    // Set key if provided, otherwise use existing key or generate one
    if (!key.empty()) {
        m_encryptionKey = key;
    } else if (m_encryptionKey.empty() && enable) {
        // Generate a simple key
        m_encryptionKey = "RobloxExecutorSecureKey123";
    }
}

// Enable or disable certificate validation
void OnlineService::SetBypassCertificateValidation(bool bypass) {
    m_bypassCertificateValidation = bypass;
}

// Clear response cache
void OnlineService::ClearCache() {
    m_responseCache.clear();
}

// Create a POST request for AI processing
OnlineService::Request OnlineService::CreateAIRequest(const std::string& endpoint, 
                                                   const std::string& query,
                                                   const std::string& context,
                                                   const std::string& requestType) {
    Request request;
    request.m_endpoint = endpoint;
    request.m_method = "POST";
    request.m_timeoutMs = m_defaultTimeoutMs;
    
    // Create JSON body
    std::stringstream ss;
    ss << "{";
    ss << "\"query\":\"" << EscapeJSON(query) << "\"";
    
    if (!context.empty()) {
        ss << ",\"context\":\"" << EscapeJSON(context) << "\"";
    }
    
    if (!requestType.empty()) {
        ss << ",\"type\":\"" << EscapeJSON(requestType) << "\"";
    }
    
    ss << ",\"timestamp\":" << std::chrono::duration_cast<std::chrono::seconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
        
    ss << "}";
    
    request.m_body = ss.str();
    request.m_headers.push_back(std::make_pair("Content-Type", "application/json"));
    
    return request;
}

// Parse AI response
std::string OnlineService::ParseAIResponse(const Response& response) {
    // Check if response is successful
    if (!response.m_success) {
        return "Error: " + response.m_errorMessage;
    }
    
    // Parse JSON response
    // In a real implementation, use a proper JSON parser
    std::string content = response.m_body;
    
    // Simple extraction of content field from JSON
    size_t contentStart = content.find("\"content\":\"");
    if (contentStart != std::string::npos) {
        contentStart += 11; // Length of "content":"
        size_t contentEnd = content.find("\"", contentStart);
        if (contentEnd != std::string::npos) {
            return UnescapeJSON(content.substr(contentStart, contentEnd - contentStart));
        }
    }
    
    // Fallback - return the whole body
    return content;
}

// Create a standard API GET request
OnlineService::Request OnlineService::CreateGETRequest(const std::string& endpoint,
                                                    const std::unordered_map<std::string, std::string>& queryParams) {
    Request request;
    request.m_method = "GET";
    
    // Build endpoint with query parameters
    std::string fullEndpoint = endpoint;
    if (!queryParams.empty()) {
        fullEndpoint += "?";
        bool first = true;
        
        for (const auto& param : queryParams) {
            if (!first) {
                fullEndpoint += "&";
            }
            
            // URL encode key and value
            fullEndpoint += URLEncode(param.first) + "=" + URLEncode(param.second);
            first = false;
        }
    }
    
    request.m_endpoint = fullEndpoint;
    request.m_timeoutMs = m_defaultTimeoutMs;
    
    return request;
}

// Create a standard API POST request
OnlineService::Request OnlineService::CreatePOSTRequest(const std::string& endpoint,
                                                     const std::string& body,
                                                     const std::string& contentType) {
    Request request;
    request.m_endpoint = endpoint;
    request.m_method = "POST";
    request.m_body = body;
    request.m_timeoutMs = m_defaultTimeoutMs;
    
    // Add content type header
    request.m_headers.push_back(std::make_pair("Content-Type", contentType));
    
    return request;
}

// Escape JSON string
std::string OnlineService::EscapeJSON(const std::string& input) {
    std::string output;
    output.reserve(input.length() * 2); // Reserve space to avoid reallocations
    
    for (char c : input) {
        switch (c) {
            case '\"': output += "\\\""; break;
            case '\\': output += "\\\\"; break;
            case '\b': output += "\\b"; break;
            case '\f': output += "\\f"; break;
            case '\n': output += "\\n"; break;
            case '\r': output += "\\r"; break;
            case '\t': output += "\\t"; break;
            default:
                if (c < 32) {
                    // Encode control characters
                    char buffer[7];
                    snprintf(buffer, sizeof(buffer), "\\u%04x", c);
                    output += buffer;
                } else {
                    output += c;
                }
                break;
        }
    }
    
    return output;
}

// Unescape JSON string
std::string OnlineService::UnescapeJSON(const std::string& input) {
    std::string output;
    output.reserve(input.length()); // Reserve space to avoid reallocations
    
    for (size_t i = 0; i < input.length(); ++i) {
        if (input[i] == '\\' && i + 1 < input.length()) {
            switch (input[i + 1]) {
                case '\"': output += '\"'; break;
                case '\\': output += '\\'; break;
                case 'b': output += '\b'; break;
                case 'f': output += '\f'; break;
                case 'n': output += '\n'; break;
                case 'r': output += '\r'; break;
                case 't': output += '\t'; break;
                case 'u':
                    // Unicode escape sequence
                    if (i + 5 < input.length()) {
                        // Parse hex value
                        std::string hex = input.substr(i + 2, 4);
                        int value = 0;
                        sscanf(hex.c_str(), "%x", &value);
                        
                        // Append UTF-8 encoded character
                        if (value < 0x80) {
                            output += static_cast<char>(value);
                        } else if (value < 0x800) {
                            output += static_cast<char>(0xC0 | (value >> 6));
                            output += static_cast<char>(0x80 | (value & 0x3F));
                        } else {
                            output += static_cast<char>(0xE0 | (value >> 12));
                            output += static_cast<char>(0x80 | ((value >> 6) & 0x3F));
                            output += static_cast<char>(0x80 | (value & 0x3F));
                        }
                        
                        i += 5; // Skip \uXXXX
                    } else {
                        output += "\\u"; // Invalid unicode escape
                        i += 1;
                    }
                    break;
                default:
                    output += input[i + 1];
                    break;
            }
            ++i; // Skip the escaped character
        } else {
            output += input[i];
        }
    }
    
    return output;
}

// URL encode string
std::string OnlineService::URLEncode(const std::string& input) {
    std::string output;
    output.reserve(input.length() * 3); // Reserve space for worst case
    
    for (char c : input) {
        if (isalnum(c) || c == '-' || c == '_' || c == '.' || c == '~') {
            output += c;
        } else if (c == ' ') {
            output += '+';
        } else {
            output += '%';
            char buffer[3];
            snprintf(buffer, sizeof(buffer), "%02X", static_cast<unsigned char>(c));
            output += buffer;
        }
    }
    
    return output;
}

} // namespace AIFeatures
} // namespace iOS
