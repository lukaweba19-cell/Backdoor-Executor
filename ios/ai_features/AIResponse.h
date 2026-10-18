#pragma once

#include <string>
#include <vector>
#include <unordered_map>

namespace iOS {
namespace AIFeatures {

/**
 * @struct AIResponse
 * @brief Structure for AI query responses
 * 
 * This structure encapsulates a response from the AI system to a user query,
 * including the generated content and any additional information or suggestions.
 */
struct AIResponse {
    // Response text from the assistant
    std::string m_response;
    
    // Suggestions for follow-up queries
    std::vector<std::string> m_suggestions;
    
    // Additional data related to the response
    std::unordered_map<std::string, std::string> m_additionalData;
    
    // Response timestamp
    uint64_t m_timestamp;
    
    // Whether the response was generated without network (always false now)
    bool m_generatedOffline;
    
    // Response confidence (0.0-1.0)
    float m_confidence;
    
    // Constructor
    AIResponse() 
        : m_timestamp(0), m_generatedOffline(false), m_confidence(0.0f) {}
    
    // Constructor with response
    AIResponse(const std::string& response) 
        : m_response(response), m_timestamp(0), m_generatedOffline(false), m_confidence(0.0f) {}
    
    // Constructor with response and confidence
    AIResponse(const std::string& response, float confidence)
        : m_response(response), m_timestamp(0), m_generatedOffline(false), m_confidence(confidence) {}
};

} // namespace AIFeatures
} // namespace iOS