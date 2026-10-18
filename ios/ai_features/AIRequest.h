#pragma once

#include <string>
#include <vector>
#include <unordered_map>

namespace iOS {
namespace AIFeatures {

/**
 * @struct AIRequest
 * @brief Structure for AI query requests
 * 
 * This structure encapsulates a user query to the AI system along with
 * any context information needed to generate an appropriate response.
 */
struct AIRequest {
    // Query text from the user
    std::string m_query;
    
    // User identifier (optional)
    std::string m_userId;
    
    // System context for the assistant
    std::string m_systemContext;
    
    // Additional context information
    std::unordered_map<std::string, std::string> m_contextData;
    
    // History of previous interactions (optional)
    std::vector<std::pair<std::string, std::string>> m_conversationHistory;
    
    // Request timestamp
    uint64_t m_timestamp;
    
    // Constructor
    AIRequest() : m_timestamp(0) {}
    
    // Constructor with query
    AIRequest(const std::string& query) 
        : m_query(query), m_timestamp(0) {}
    
    // Constructor with query and user ID
    AIRequest(const std::string& query, const std::string& userId)
        : m_query(query), m_userId(userId), m_timestamp(0) {}
};

} // namespace AIFeatures
} // namespace iOS