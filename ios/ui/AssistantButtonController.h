#pragma once

#include <string>
#include <vector>
#include <functional>
#include <memory>
#include <unordered_map>
#include "../../objc_isolation.h"

// Forward declarations
namespace iOS {
namespace AIFeatures {
// Local models removed — uses online HybridAI / C API
}
}

namespace iOS {
namespace UI {

/**
 * @class AssistantButtonController
 * @brief Controls a floating AI assistant button with a chat interface
 * 
 * This class manages a floating button that provides access to the AI assistant.
 * When tapped, it opens a chat interface where users can interact with the
 * online AI. The button adapts to the screen orientation and
 * can be positioned in different corners of the screen.
 */
class AssistantButtonController {
public:
    // Button position enumeration
    enum class Position {
        TopLeft,        // Top left corner
        TopRight,       // Top right corner
        BottomLeft,     // Bottom left corner
        BottomRight,    // Bottom right corner
        Center          // Center of screen edge
    };
    
    // Button visibility state
    enum class VisibilityState {
        Hidden,         // Not visible
        Minimized,      // Only button visible
        Visible         // Full interface visible
    };
    
    // Button appearance
    struct ButtonAppearance {
        float size;                 // Button diameter in points
        float cornerRadius;         // Corner radius in points
        float alpha;                // Transparency (0.0-1.0)
        std::string iconName;       // Icon image name
        std::string backgroundColor; // Background color (hex string)
        std::string tintColor;      // Icon tint color (hex string)
        
        ButtonAppearance() 
            : size(56.0f), cornerRadius(28.0f), alpha(0.9f),
              iconName("assistant_icon"), 
              backgroundColor("#007AFF"), tintColor("#FFFFFF") {}
    };
    
    // Message type for chat
    enum class MessageType {
        User,           // User message
        Assistant,      // Assistant response
        System,         // System message (e.g., "Connection lost")
        Action          // Action message (e.g., "Running script...")
    };
    
    // Chat message
    struct ChatMessage {
        std::string text;           // Message text
        MessageType type;           // Message type
        uint64_t timestamp;         // Message timestamp (microseconds)
        
        ChatMessage() : timestamp(0) {}
        ChatMessage(const std::string& text, MessageType type, uint64_t timestamp) 
            : text(text), type(type), timestamp(timestamp) {}
    };
    
    // Message handler callback
    using MessageHandler = std::function<std::string(const std::string&)>;
    
private:
    // Member variables
    void* m_viewController;         // Parent view controller
    void* m_button;                 // Button view
    void* m_chatView;               // Chat view
    void* m_inputField;             // Text input field
    void* m_panGestureRecognizer;   // Pan gesture for moving button
    
    Position m_position;            // Button position
    VisibilityState m_state;        // Current visibility state
    ButtonAppearance m_appearance;  // Button appearance
    std::vector<ChatMessage> m_messages; // Chat message history
    
    void* m_aiIntegration; // Opaque AIIntegration* from InitializeAI
    MessageHandler m_customMessageHandler; // Custom message handler
    
    bool m_isDragging;              // Whether button is being dragged
    float m_safeAreaInsets[4];      // Safe area insets (top, left, bottom, right)
    
    // Private helper methods
    void SetupButton();
    void SetupChatView();
    void ConfigureAppearance();
    void UpdateButtonPosition();
    void HandleButtonTap();
    void AddMessage(const std::string& text, MessageType type);
    void ProcessUserMessage(const std::string& text);
    void UpdateChatView();
    void SetButtonHidden(bool hidden);
    void SetChatViewHidden(bool hidden);
    void AnimateButtonPress();
    void AnimateChatOpen();
    void AnimateChatClose();
    void SaveMessages();
    void LoadMessages();
    void HandlePanGesture(void* gestureRecognizer);
    void AdjustForKeyboard(bool visible, float keyboardHeight);
    
public:
    /**
     * @brief Constructor
     * @param viewController Parent view controller
     */
    AssistantButtonController(void* viewController);
    
    /**
     * @brief Destructor
     */
    ~AssistantButtonController();
    
    /**
     * @brief Set button position
     * @param position Button position
     */
    void SetPosition(Position position);
    
    /**
     * @brief Set button appearance
     * @param appearance Button appearance
     */
    void SetAppearance(const ButtonAppearance& appearance);
    
    /**
     * @brief Set visibility state
     * @param state Visibility state
     */
    void SetVisibilityState(VisibilityState state);
    
    /**
     * @brief Get current visibility state
     * @return Current visibility state
     */
    VisibilityState GetVisibilityState() const;
    
    /**
     * @brief Set custom message handler
     * @param handler Message handler function
     */
    void SetMessageHandler(MessageHandler handler);
    
    /**
     * @brief Set assistant model
     * @param model Assistant model
     */
    void SetAIIntegration(void* integration); // from InitializeAI()
    
    /**
     * @brief Get assistant model
     * @return Assistant model
     */
    void* GetAIIntegration() const;
    
    /**
     * @brief Send system message to chat
     * @param message System message
     */
    void SendSystemMessage(const std::string& message);
    
    /**
     * @brief Send action message to chat
     * @param message Action message
     */
    void SendActionMessage(const std::string& message);
    
    /**
     * @brief Clear chat history
     */
    void ClearChatHistory();
    
    /**
     * @brief Get chat message history
     * @return Chat message history
     */
    std::vector<ChatMessage> GetChatHistory() const;
    
    /**
     * @brief Handle device orientation change
     */
    void HandleOrientationChange();
    
    /**
     * @brief Update safe area insets
     * @param top Top inset
     * @param left Left inset
     * @param bottom Bottom inset
     * @param right Right inset
     */
    void UpdateSafeAreaInsets(float top, float left, float bottom, float right);
};

} // namespace UI
} // namespace iOS
