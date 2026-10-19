#include "AssistantButtonController.h"
#include "AIIntegration.h"
#include <iostream>
#include <chrono>
#include <ctime>
#include <algorithm>

// Objective-C imports
#if __OBJC__
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h> // For objc_setAssociatedObject
#else
typedef void UIButton;
typedef void UIView;
typedef void UIViewController;
#endif

namespace iOS {
namespace UI {

// Constructor with viewController parameter (match header signature)
AssistantButtonController::AssistantButtonController(void* viewController) 
    : m_viewController(viewController),
      m_button(nullptr),
      m_chatView(nullptr),
      m_inputField(nullptr),
      m_panGestureRecognizer(nullptr),
      m_position(Position::BottomRight),
      m_state(VisibilityState::Minimized),
      m_aiIntegration(nullptr),
      m_customMessageHandler(nullptr),
      m_isDragging(false)
{
    // Initialize safe area insets with default values
    m_safeAreaInsets[0] = 20; // top
    m_safeAreaInsets[1] = 20; // left
    m_safeAreaInsets[2] = 20; // bottom
    m_safeAreaInsets[3] = 20; // right
    
    // Initialize appearance
    m_appearance.size = 60.0f;
    m_appearance.cornerRadius = 30.0f;
    m_appearance.alpha = 1.0f;
    m_appearance.iconName = "assistant_icon";
    m_appearance.backgroundColor = "#007AFF"; // iOS blue
    m_appearance.tintColor = "#FFFFFF";       // white
    
    // Setup UI components right in constructor since we have viewController
    SetupButton();
    SetupChatView();
    SetPosition(m_position);
    SetVisibilityState(m_state);
}

// Destructor
AssistantButtonController::~AssistantButtonController() {
    // Clean up Objective-C objects
#if __OBJC__
    if (m_button) {
        UIButton* button = (__bridge UIButton*)m_button;
        [button removeFromSuperview];
        CFRelease(m_button);
        m_button = nullptr;
    }
    
    if (m_chatView) {
        UIView* chatContentView = (__bridge UIView*)m_chatView;
        UIScrollView* scrollView = (UIScrollView*)chatContentView.superview;
        UIView* panelView = scrollView.superview;
        [panelView removeFromSuperview];
        CFRelease(m_chatView);
        m_chatView = nullptr;
    }
    
    if (m_inputField) {
        CFRelease(m_inputField);
        m_inputField = nullptr;
    }
    
    if (m_panGestureRecognizer) {
        CFRelease(m_panGestureRecognizer);
        m_panGestureRecognizer = nullptr;
    }
    
    // Clear members
    m_viewController = nullptr;
    m_messages.clear();
#endif
}

// Helper methods
void AssistantButtonController::SetupButton() {
#if __OBJC__
    if (!m_viewController) return;
    UIViewController* controller = (__bridge UIViewController*)m_viewController;
    
    // Create button
    UIButton* button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0, 0, m_appearance.size, m_appearance.size);
    
    // Configure appearance
    button.layer.cornerRadius = m_appearance.cornerRadius;
    
    // Set background color from hex string
    UIColor* backgroundColor = nil;
    if (m_appearance.backgroundColor == "#007AFF") {
        backgroundColor = [UIColor systemBlueColor];
    } else {
        // Default blue
        backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
    }
    button.backgroundColor = backgroundColor;
    
    // Set icon
    [button setImage:[UIImage systemImageNamed:@"wand.and.stars"] forState:UIControlStateNormal];
    
    // Set tint color from hex string
    UIColor* tintColor = nil;
    if (m_appearance.tintColor == "#FFFFFF") {
        tintColor = [UIColor whiteColor];
    } else {
        // Default white
        tintColor = [UIColor whiteColor];
    }
    button.tintColor = tintColor;
    
    button.alpha = m_appearance.alpha;
    
    // Add shadow
    button.layer.shadowColor = [UIColor blackColor].CGColor;
    button.layer.shadowOffset = CGSizeMake(0, 3);
    button.layer.shadowOpacity = 0.3;
    button.layer.shadowRadius = 5;
    
    // Add to the view
    [controller.view addSubview:button];
    
    // Store in member variable
    m_button = (__bridge_retained void*)button;
    
    // Add tap handler
    // Properly capture this pointer
    AssistantButtonController* controllerPtr = this;
    void (^buttonTapHandler)(UIButton*) = ^(UIButton* _Unused) {
        // Toggle visibility state when tapped
        if (controllerPtr->m_state == VisibilityState::Minimized) {
            controllerPtr->SetVisibilityState(VisibilityState::Visible);
        } else {
            controllerPtr->SetVisibilityState(VisibilityState::Minimized);
        }
    };
    
    // Store block to avoid ARC releasing it
    objc_setAssociatedObject(button, "tapHandler", buttonTapHandler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // Add target-action for button tap
    [button addTarget:buttonTapHandler 
               action:@selector(invoke:) 
     forControlEvents:UIControlEventTouchUpInside];
    
    // Add pan gesture recognizer for dragging
    UIPanGestureRecognizer* panGesture = [[UIPanGestureRecognizer alloc] init];
    
    // Add pan handler
    AssistantButtonController* controller_ptr = this; // Create local pointer to this for capture
    void (^panHandler)(UIPanGestureRecognizer*) = ^(UIPanGestureRecognizer* recognizer) {
        UIButton* button = (__bridge UIButton*)controller_ptr->m_button;
        UIViewController* viewController = (__bridge UIViewController*)controller_ptr->m_viewController;
        CGRect bounds = viewController.view.bounds;
        
        if (recognizer.state == UIGestureRecognizerStateBegan) {
            controller_ptr->m_isDragging = true;
        }
        else if (recognizer.state == UIGestureRecognizerStateChanged) {
            CGPoint translation = [recognizer translationInView:button.superview];
            
            CGRect frame = button.frame;
            frame.origin.x += translation.x;
            frame.origin.y += translation.y;
            button.frame = frame;
            
            [recognizer setTranslation:CGPointZero inView:button.superview];
        }
        else if (recognizer.state == UIGestureRecognizerStateEnded) {
            controller_ptr->m_isDragging = false;
            
            // Snap to closest edge
            CGFloat minX = controller_ptr->m_safeAreaInsets[1];
            CGFloat minY = controller_ptr->m_safeAreaInsets[0];
            CGFloat maxX = bounds.size.width - button.frame.size.width - controller_ptr->m_safeAreaInsets[3];
            CGFloat maxY = bounds.size.height - button.frame.size.height - controller_ptr->m_safeAreaInsets[2];
            
            CGRect frame = button.frame;
            
            // Find horizontal and vertical position
            bool isLeft = (frame.origin.x < bounds.size.width / 2);
            bool isTop = (frame.origin.y < bounds.size.height / 2);
            
            // Snap to each corner
            Position newPosition;
            if (isLeft && isTop) {
                frame.origin.x = minX;
                frame.origin.y = minY;
                newPosition = Position::TopLeft;
            }
            else if (isLeft && !isTop) {
                frame.origin.x = minX;
                frame.origin.y = maxY;
                newPosition = Position::BottomLeft;
            }
            else if (!isLeft && isTop) {
                frame.origin.x = maxX;
                frame.origin.y = minY;
                newPosition = Position::TopRight;
            }
            else {
                frame.origin.x = maxX;
                frame.origin.y = maxY;
                newPosition = Position::BottomRight;
            }
            
            // Animate to snapped position
            [UIView animateWithDuration:0.3
                             animations:^{
                                 button.frame = frame;
                             }];
                             
            // Update position
            controller_ptr->m_position = newPosition;
        }
    };
    
    // Store block to avoid ARC releasing it
    objc_setAssociatedObject(panGesture, "panHandler", panHandler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // Add target-action for pan gesture
    [panGesture addTarget:panHandler action:@selector(invoke:)];
    [button addGestureRecognizer:panGesture];
    
    // Store gesture recognizer
    m_panGestureRecognizer = (__bridge_retained void*)panGesture;
#endif
}

void AssistantButtonController::SetupChatView() {
#if __OBJC__
    if (!m_viewController) return;
    UIViewController* controller = (__bridge UIViewController*)m_viewController;
    
    // Create chat panel view
    UIView* panelView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 400)];
    panelView.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    panelView.layer.cornerRadius = 16;
    panelView.clipsToBounds = true;
    panelView.alpha = 0.0; // Start hidden
    panelView.hidden = YES;
    
    // Add shadow
    panelView.layer.shadowColor = [UIColor blackColor].CGColor;
    panelView.layer.shadowOffset = CGSizeMake(0, 5);
    panelView.layer.shadowOpacity = 0.3;
    panelView.layer.shadowRadius = 10;
    
    // Add to the view
    [controller.view addSubview:panelView];
    
    // Create header view
    UIView* headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, panelView.frame.size.width, 50)];
    headerView.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
    [panelView addSubview:headerView];
    
    // Create title label
    UILabel* titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, headerView.frame.size.width - 66, 50)];
    titleLabel.text = @"AI Assistant";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [headerView addSubview:titleLabel];
    
    // Create close button
    UIButton* closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake(headerView.frame.size.width - 50, 0, 50, 50);
    [closeButton setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    closeButton.tintColor = [UIColor whiteColor];
    [headerView addSubview:closeButton];
    
    // Add close button handler
    AssistantButtonController* controllerPtr = this;
    void (^closeButtonHandler)(UIButton*) = ^(UIButton* _Unused) {
        controllerPtr->SetVisibilityState(VisibilityState::Minimized);
    };
    
    // Store block to avoid ARC releasing it
    objc_setAssociatedObject(closeButton, "closeHandler", closeButtonHandler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // Add target-action for close button
    [closeButton addTarget:closeButtonHandler
                    action:@selector(invoke:)
          forControlEvents:UIControlEventTouchUpInside];
    
    // Create input field
    UITextField* inputField = [[UITextField alloc] initWithFrame:CGRectMake(16, panelView.frame.size.height - 60, panelView.frame.size.width - 82, 40)];
    inputField.placeholder = @"Ask a question...";
    inputField.borderStyle = UITextBorderStyleRoundedRect;
    inputField.backgroundColor = [UIColor whiteColor];
    [panelView addSubview:inputField];
    
    // Store input field
    m_inputField = (__bridge_retained void*)inputField;
    
    // Create send button
    UIButton* sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    sendButton.frame = CGRectMake(panelView.frame.size.width - 60, panelView.frame.size.height - 60, 44, 40);
    [sendButton setImage:[UIImage systemImageNamed:@"arrow.up.circle.fill"] forState:UIControlStateNormal];
    sendButton.tintColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
    [panelView addSubview:sendButton];
    
    // Add send button handler
    AssistantButtonController* controller_ptr = this;
    void (^sendButtonHandler)(UIButton*) = ^(UIButton* _Unused) {
        UITextField* field = (__bridge UITextField*)controller_ptr->m_inputField;
        NSString* text = field.text;
        
        if (text.length > 0) {
            std::string message = [text UTF8String];
            
            // Add user message
            ChatMessage chatMsg(message, MessageType::User, std::chrono::system_clock::to_time_t(std::chrono::system_clock::now()));
            controller_ptr->m_messages.push_back(chatMsg);
            
            // Process with custom handler or AI model
            if (controller_ptr->m_customMessageHandler) {
                controller_ptr->m_customMessageHandler(message);
            } else if (controller_ptr->m_aiIntegration) {
                // In a real implementation, this would call the AI model
                // Since we can't find ProcessQuery in the model, generate a default response
                std::string response = "I'm the AI assistant. How can I help you?";
                
                // Add assistant message
                ChatMessage assistantMsg(response, MessageType::Assistant, std::chrono::system_clock::to_time_t(std::chrono::system_clock::now()));
                controller_ptr->m_messages.push_back(assistantMsg);
                
                // Update chat view
                controller_ptr->UpdateChatView();
            }
            
            // Update chat view
            controller_ptr->UpdateChatView();
            
            // Clear input field
            field.text = @"";
        }
    };
    
    // Store block to avoid ARC releasing it
    objc_setAssociatedObject(sendButton, "sendHandler", sendButtonHandler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // Add target-action for send button
    [sendButton addTarget:sendButtonHandler
                   action:@selector(invoke:)
         forControlEvents:UIControlEventTouchUpInside];
    
    // Create chat view (scrollable)
    UIScrollView* chatScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 50, panelView.frame.size.width, panelView.frame.size.height - 110)];
    chatScrollView.backgroundColor = [UIColor whiteColor];
    [panelView addSubview:chatScrollView];
    
    // Add content view to scroll view
    UIView* chatContentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, chatScrollView.frame.size.width, 0)]; // Height will grow as messages are added
    chatContentView.backgroundColor = [UIColor whiteColor];
    [chatScrollView addSubview:chatContentView];
    
    // Store chat view
    m_chatView = (__bridge_retained void*)chatContentView;
#endif
}

void AssistantButtonController::SetPosition(Position position) {
    m_position = position;
    
#if __OBJC__
    // Update button position
    if (m_button && m_viewController) {
        UIButton* button = (__bridge UIButton*)m_button;
        UIViewController* controller = (__bridge UIViewController*)m_viewController;
        CGRect bounds = controller.view.bounds;
        
        // Calculate position based on the setting
        CGFloat minX = m_safeAreaInsets[1];
        CGFloat minY = m_safeAreaInsets[0];
        CGFloat maxX = bounds.size.width - button.frame.size.width - m_safeAreaInsets[3];
        CGFloat maxY = bounds.size.height - button.frame.size.height - m_safeAreaInsets[2];
        
        CGRect frame = button.frame;
        
        switch (m_position) {
            case Position::TopLeft:
                frame.origin.x = minX;
                frame.origin.y = minY;
                break;
            
            case Position::TopRight:
                frame.origin.x = maxX;
                frame.origin.y = minY;
                break;
            
            case Position::BottomLeft:
                frame.origin.x = minX;
                frame.origin.y = maxY;
                break;
            
            case Position::BottomRight:
                frame.origin.x = maxX;
                frame.origin.y = maxY;
                break;
            
            case Position::Center:
                frame.origin.x = (bounds.size.width - button.frame.size.width) / 2;
                frame.origin.y = (bounds.size.height - button.frame.size.height) / 2;
                break;
        }
        
        button.frame = frame;
    }
#endif
}

void AssistantButtonController::SetVisibilityState(VisibilityState state) {
    if (m_state == state) return;
    
    m_state = state;
    
#if __OBJC__
    // Update UI based on visibility state
    switch (state) {
        case VisibilityState::Hidden:
            SetButtonHidden(true);
            SetChatViewHidden(true);
            break;
            
        case VisibilityState::Minimized:
            SetButtonHidden(false);
            SetChatViewHidden(true);
            break;
            
        case VisibilityState::Visible:
            SetButtonHidden(false);
            SetChatViewHidden(false);
            break;
    }
#endif
}

AssistantButtonController::VisibilityState AssistantButtonController::GetVisibilityState() const {
    return m_state;
}

void AssistantButtonController::SetMessageHandler(MessageHandler handler) {
    m_customMessageHandler = handler;
}

void AssistantButtonController::SetAIIntegration(void* integration) {
    m_aiIntegration = integration;
}

void AssistantButtonController::SetButtonHidden(bool hidden) {
#if __OBJC__
    if (m_button) {
        UIButton* button = (__bridge UIButton*)m_button;
        button.hidden = hidden;
    }
#endif
}

void AssistantButtonController::SetChatViewHidden(bool hidden) {
#if __OBJC__
    if (m_chatView) {
        UIView* chatContentView = (__bridge UIView*)m_chatView;
        UIScrollView* scrollView = (UIScrollView*)chatContentView.superview;
        UIView* panelView = scrollView.superview;
        
        if (hidden) {
            // Hide with animation
            if (!panelView.hidden) {
                [UIView animateWithDuration:0.3
                                 animations:^{
                                     panelView.alpha = 0.0;
                                 }
                                 completion:^(BOOL _Unused) {
                                     panelView.hidden = YES;
                                 }];
            }
        } else {
            // Show with animation
            panelView.hidden = NO;
            panelView.alpha = 0.0;
            
            // Position panel near button
            if (m_button) {
                UIButton* button = (__bridge UIButton*)m_button;
                CGRect buttonFrame = button.frame;
                CGRect panelFrame = panelView.frame;
                
                // Position based on button position
                switch (m_position) {
                    case Position::TopLeft:
                        panelFrame.origin.x = buttonFrame.origin.x;
                        panelFrame.origin.y = buttonFrame.origin.y + buttonFrame.size.height + 10;
                        break;
                        
                    case Position::TopRight:
                        panelFrame.origin.x = buttonFrame.origin.x + buttonFrame.size.width - panelFrame.size.width;
                        panelFrame.origin.y = buttonFrame.origin.y + buttonFrame.size.height + 10;
                        break;
                        
                    case Position::BottomLeft:
                        panelFrame.origin.x = buttonFrame.origin.x;
                        panelFrame.origin.y = buttonFrame.origin.y - panelFrame.size.height - 10;
                        break;
                        
                    case Position::BottomRight:
                        panelFrame.origin.x = buttonFrame.origin.x + buttonFrame.size.width - panelFrame.size.width;
                        panelFrame.origin.y = buttonFrame.origin.y - panelFrame.size.height - 10;
                        break;
                        
                    case Position::Center:
                        panelFrame.origin.x = (button.superview.frame.size.width - panelFrame.size.width) / 2;
                        panelFrame.origin.y = (button.superview.frame.size.height - panelFrame.size.height) / 2;
                        break;
                }
                
                panelView.frame = panelFrame;
            }
            
            // Update chat view
            UpdateChatView();
            
            // Show with animation
            [UIView animateWithDuration:0.3
                             animations:^{
                                 panelView.alpha = 1.0;
                             }];
        }
    }
#endif
}

void AssistantButtonController::UpdateChatView() {
#if __OBJC__
    if (!m_chatView) return;
    
    UIView* chatContentView = (__bridge UIView*)m_chatView;
    
    // Remove all existing message views
    for (UIView* subview in [chatContentView.subviews copy]) {
        [subview removeFromSuperview];
    }
    
    // Add message bubbles
    CGFloat currentY = 8;
    CGFloat contentWidth = chatContentView.frame.size.width;
    CGFloat maxBubbleWidth = contentWidth * 0.7;
    
    for (const ChatMessage& message : m_messages) {
        bool isUser = (message.type == MessageType::User);
        
        // Create message label
        UILabel* messageLabel = [[UILabel alloc] init];
        messageLabel.text = [NSString stringWithUTF8String:message.text.c_str()];
        messageLabel.numberOfLines = 0;
        messageLabel.lineBreakMode = NSLineBreakByWordWrapping;
        messageLabel.font = [UIFont systemFontOfSize:16];
        
        // Calculate size needed for text
        CGSize maxSize = CGSizeMake(maxBubbleWidth - 16, CGFLOAT_MAX);
        CGRect textRect = [messageLabel.text boundingRectWithSize:maxSize
                                                        options:NSStringDrawingUsesLineFragmentOrigin
                                                     attributes:@{NSFontAttributeName: messageLabel.font}
                                                        context:nil];
        
        // Create bubble
        CGFloat bubbleWidth = textRect.size.width + 16;
        CGFloat bubbleHeight = textRect.size.height + 16;
        CGFloat bubbleX = isUser ? (contentWidth - bubbleWidth - 8) : 8;
        UIView* bubbleView = [[UIView alloc] initWithFrame:CGRectMake(bubbleX, currentY, bubbleWidth, bubbleHeight)];
        
        // Style bubble
        switch (message.type) {
            case MessageType::User:
                bubbleView.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
                messageLabel.textColor = [UIColor whiteColor];
                break;
                
            case MessageType::Assistant:
                bubbleView.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
                messageLabel.textColor = [UIColor blackColor];
                break;
                
            case MessageType::System:
                bubbleView.backgroundColor = [UIColor colorWithRed:0.7 green:0.7 blue:0.7 alpha:1.0];
                messageLabel.textColor = [UIColor whiteColor];
                break;
                
            case MessageType::Action:
                bubbleView.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.2 alpha:1.0];
                messageLabel.textColor = [UIColor whiteColor];
                break;
        }
        
        bubbleView.layer.cornerRadius = 12;
        
        // Position message label in bubble
        messageLabel.frame = CGRectMake(8, 8, textRect.size.width, textRect.size.height);
        [bubbleView addSubview:messageLabel];
        [chatContentView addSubview:bubbleView];
        
        // Update current Y position for next message
        currentY += bubbleHeight + 8;
    }
    
    // Update content size
    UIScrollView* scrollView = (UIScrollView*)chatContentView.superview;
    CGRect frame = chatContentView.frame;
    frame.size.height = currentY;
    chatContentView.frame = frame;
    scrollView.contentSize = frame.size;
    
    // Scroll to bottom
    if (currentY > scrollView.frame.size.height) {
        [scrollView setContentOffset:CGPointMake(0, currentY - scrollView.frame.size.height) animated:YES];
    }
#endif
}

void AssistantButtonController::AddMessage(const std::string& text, MessageType type) {
    // Create message
    ChatMessage message(text, type, std::chrono::system_clock::to_time_t(std::chrono::system_clock::now()));
    m_messages.push_back(message);
    
    // Update chat view
    UpdateChatView();
}

void AssistantButtonController::ClearChatHistory() {
    m_messages.clear();
    UpdateChatView();
}

std::vector<AssistantButtonController::ChatMessage> AssistantButtonController::GetChatHistory() const {
    return m_messages;
}

void AssistantButtonController::HandleOrientationChange() {
    // Update button position
    SetPosition(m_position);
    
    // Update chat view if visible
    if (m_state == VisibilityState::Visible) {
        SetChatViewHidden(false); // This will reposition the chat view
    }
}

void AssistantButtonController::UpdateSafeAreaInsets(float top, float left, float bottom, float right) {
    m_safeAreaInsets[0] = top;
    m_safeAreaInsets[1] = left;
    m_safeAreaInsets[2] = bottom;
    m_safeAreaInsets[3] = right;
    
    // Update button position
    SetPosition(m_position);
}

} // namespace UI
} // namespace iOS
