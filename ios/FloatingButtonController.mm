
#include "ios_impl_compat.h"
#include "FloatingButtonController.h"
#include <iostream>
#include "ui/UIDesignSystem.h"

// Import CoreFoundation for bridging functions
#if __has_feature(objc_arc)
#import <CoreFoundation/CoreFoundation.h>
#endif

// Forward declarations of helper functions
static CALayer* createLEDGlowLayer(CGRect frame, UIColor* color, CGFloat intensity);
static CABasicAnimation* createPulseAnimation(CGFloat duration, CGFloat intensity);
static void applyHapticFeedback(UIImpactFeedbackStyle style);

// Objective-C++ implementation of the button view
@interface FloatingButton : UIButton

@property (nonatomic, assign) iOS::FloatingButtonController* controller;
@property (nonatomic, assign) BOOL draggable;
@property (nonatomic, assign) CGPoint touchOffset;
@property (nonatomic, strong) CALayer* glowLayer;
@property (nonatomic, strong) CALayer* pulseLayer;
@property (nonatomic, strong) UIColor* ledColor;
@property (nonatomic, assign) CGFloat ledIntensity;
@property (nonatomic, assign) BOOL usesHapticFeedback;
@property (nonatomic, strong) UILongPressGestureRecognizer* longPressGesture;
@property (nonatomic, strong) UIView* quickActionMenu;

- (void)setupLEDEffects;
- (void)updateLEDColor:(UIColor*)color intensity:(CGFloat)intensity;
- (void)triggerPulseEffect;
- (void)showQuickActionMenu;
- (void)hideQuickActionMenu;

@end

@implementation FloatingButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.draggable = YES;
        self.layer.cornerRadius = frame.size.width / 2.0;
        self.layer.masksToBounds = NO; // Allow glow to extend outside button
        self.backgroundColor = [UIColor colorWithRed:0.1 green:0.6 blue:0.9 alpha:0.8];
        self.ledColor = [UIColor colorWithRed:0.2 green:0.8 blue:1.0 alpha:1.0]; // Default LED color
        self.ledIntensity = 0.8;
        self.usesHapticFeedback = YES;
        
        // Add an icon or text
        [self setImage:[UIImage systemImageNamed:@"terminal"] forState:UIControlStateNormal];
        self.tintColor = [UIColor whiteColor];
        
        // Add shadow for depth
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOffset = CGSizeMake(0, 3);
        self.layer.shadowOpacity = 0.5;
        self.layer.shadowRadius = 6.0;
        
        // Setup LED glow effects
        [self setupLEDEffects];
        
        // Add long press gesture recognizer for quick actions
        self.longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        self.longPressGesture.minimumPressDuration = 0.5;
        [self addGestureRecognizer:self.longPressGesture];
        
        // Add a scale-up animation on creation
        self.transform = CGAffineTransformMakeScale(0.1, 0.1);
        [UIView animateWithDuration:0.4
                              delay:0
             usingSpringWithDamping:0.6
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             self.transform = CGAffineTransformIdentity;
                             self.glowLayer.opacity = 1.0;
                         }
                         completion:^(BOOL finished) {
                             [self triggerPulseEffect];
                         }];
    }
    return self;
}

- (void)setupLEDEffects {
    // Create a glow layer
    CGRect glowFrame = CGRectInset(self.bounds, -10, -10); // Larger than button for glow effect
    self.glowLayer = createLEDGlowLayer(glowFrame, self.ledColor, self.ledIntensity);
    self.glowLayer.opacity = 0.0; // Start invisible
    [self.layer insertSublayer:self.glowLayer atIndex:0]; // Place behind button content
    
    // Create a pulse layer (for animations)
    self.pulseLayer = createLEDGlowLayer(glowFrame, self.ledColor, self.ledIntensity * 0.7);
    self.pulseLayer.opacity = 0.0;
    [self.layer insertSublayer:self.pulseLayer atIndex:0];
    
    // Start a subtle breathing animation
    [self startBreathingAnimation];
}

- (void)startBreathingAnimation {
    CABasicAnimation *breathingAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    breathingAnimation.fromValue = @(0.7);
    breathingAnimation.toValue = @(1.0);
    breathingAnimation.duration = 2.0;
    breathingAnimation.autoreverses = YES;
    breathingAnimation.repeatCount = HUGE_VALF;
    breathingAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    
    [self.glowLayer addAnimation:breathingAnimation forKey:@"breathing"];
}

- (void)updateLEDColor:(UIColor*)color intensity:(CGFloat)intensity {
    // Update stored properties
    self.ledColor = color;
    self.ledIntensity = intensity;
    
    // Update glow layers
    self.glowLayer.shadowColor = color.CGColor;
    self.glowLayer.borderColor = color.CGColor;
    
    self.pulseLayer.shadowColor = color.CGColor;
    self.pulseLayer.borderColor = color.CGColor;
    
    // Adjust the opacity based on intensity
    self.glowLayer.shadowOpacity = intensity;
    self.glowLayer.borderWidth = 2.0 * intensity;
    
    // Update the button tint to match
    CGFloat red, green, blue, alpha;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    self.backgroundColor = [UIColor colorWithRed:red * 0.7 green:green * 0.7 blue:blue * 0.7 alpha:0.8];
}

- (void)triggerPulseEffect {
    // Create pulse animation
    CABasicAnimation* pulseAnimation = createPulseAnimation(1.2, self.ledIntensity);
    
    // Apply to pulse layer
    self.pulseLayer.opacity = 1.0;
    [self.pulseLayer addAnimation:pulseAnimation forKey:@"pulse"];
    
    // Hide pulse layer after animation
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.pulseLayer.opacity = 0.0;
    });
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        if (self.usesHapticFeedback) {
            applyHapticFeedback(UIImpactFeedbackStyleMedium);
        }
        [self showQuickActionMenu];
    }
}

- (void)showQuickActionMenu {
    // Remove existing menu if any
    [self hideQuickActionMenu];
    
    // Create quick action menu
    CGFloat menuRadius = 130.0;
    CGFloat buttonRadius = 40.0;
    CGPoint center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
    
    self.quickActionMenu = [[UIView alloc] initWithFrame:CGRectMake(
        center.x - menuRadius, 
        center.y - menuRadius, 
        menuRadius * 2, 
        menuRadius * 2)];
    self.quickActionMenu.alpha = 0.0;
    self.quickActionMenu.layer.cornerRadius = menuRadius;
    
    // Convert center to superview coordinates
    CGPoint superviewCenter = [self convertPoint:center toView:self.superview];
    self.quickActionMenu.center = superviewCenter;
    
    // Add background blur
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.frame = self.quickActionMenu.bounds;
    blurView.layer.cornerRadius = menuRadius;
    blurView.clipsToBounds = YES;
    [self.quickActionMenu addSubview:blurView];
    
    // Add action buttons in a circle
    NSArray *actions = @[
        @{@"icon": @"doc.text", @"tag": @(1), @"color": [UIColor systemBlueColor]},
        @{@"icon": @"play.fill", @"tag": @(2), @"color": [UIColor systemGreenColor]},
        @{@"icon": @"gear", @"tag": @(3), @"color": [UIColor systemOrangeColor]},
        @{@"icon": @"xmark", @"tag": @(4), @"color": [UIColor systemRedColor]}
    ];
    
    // Calculate positions in a circle
    CGFloat angleIncrement = 2 * M_PI / actions.count;
    CGFloat currentAngle = -M_PI / 2; // Start from top
    
    for (int i = 0; i < actions.count; i++) {
        NSDictionary *action = actions[i];
        CGFloat x = menuRadius + (menuRadius - buttonRadius) * cos(currentAngle);
        CGFloat y = menuRadius + (menuRadius - buttonRadius) * sin(currentAngle);
        
        UIButton *actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
        actionButton.frame = CGRectMake(x - buttonRadius/2, y - buttonRadius/2, buttonRadius, buttonRadius);
        actionButton.layer.cornerRadius = buttonRadius / 2;
        actionButton.backgroundColor = [action[@"color"] colorWithAlphaComponent:0.3];
        actionButton.tintColor = [UIColor whiteColor];
        actionButton.tag = [action[@"tag"] integerValue];
        
        // Create SF Symbol image
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
        UIImage *icon = [UIImage systemImageNamed:action[@"icon"] withConfiguration:config];
        [actionButton setImage:icon forState:UIControlStateNormal];
        
        // Add glow effect
        actionButton.layer.shadowColor = [action[@"color"] CGColor];
        actionButton.layer.shadowOffset = CGSizeMake(0, 0);
        actionButton.layer.shadowRadius = 10.0;
        actionButton.layer.shadowOpacity = 0.8;
        
        [actionButton addTarget:self action:@selector(handleQuickAction:) forControlEvents:UIControlEventTouchUpInside];
        
        [self.quickActionMenu addSubview:actionButton];
        
        currentAngle += angleIncrement;
    }
    
    // Add menu to superview
    [self.superview addSubview:self.quickActionMenu];
    
    // Animate it in
    [UIView animateWithDuration:0.3 animations:^{
        self.quickActionMenu.alpha = 1.0;
        self.quickActionMenu.transform = CGAffineTransformMakeScale(1.05, 1.05);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.2 animations:^{
            self.quickActionMenu.transform = CGAffineTransformIdentity;
        }];
    }];
}

- (void)hideQuickActionMenu {
    if (self.quickActionMenu) {
        [UIView animateWithDuration:0.2 animations:^{
            self.quickActionMenu.alpha = 0.0;
            self.quickActionMenu.transform = CGAffineTransformMakeScale(0.8, 0.8);
        } completion:^(BOOL finished) {
            [self.quickActionMenu removeFromSuperview];
            self.quickActionMenu = nil;
        }];
    }
}

- (void)handleQuickAction:(UIButton *)sender {
    if (self.usesHapticFeedback) {
        applyHapticFeedback(UIImpactFeedbackStyleLight);
    }
    
    // Hide menu first
    [self hideQuickActionMenu];
    
    // Get the tag to identify which action was selected
    NSInteger tag = sender.tag;
    
    // Perform action based on tag
    if (self.controller) {
        // In a real implementation, this would call the appropriate method on the controller
        // For now, just trigger the pulse effect and notify the controller
        [self triggerPulseEffect];
        
        // Execute last script (tag 2 is the play button)
        if (tag == 2) {
            // Call the tap callback which usually executes the script
            self.controller->performTapAction();
        }
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint touchPoint = [touch locationInView:self];
    self.touchOffset = touchPoint;
    
    // Apply haptic feedback
    if (self.usesHapticFeedback) {
        applyHapticFeedback(UIImpactFeedbackStyleLight);
    }
    
    // Add scale-down animation with glow increase
    [UIView animateWithDuration:0.1 animations:^{
        self.transform = CGAffineTransformMakeScale(0.95, 0.95);
        self.glowLayer.opacity = 1.3; // Increase glow on touch
    }];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.draggable) return;
    
    // Hide quick action menu if it's showing
    [self hideQuickActionMenu];
    
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self.superview];
    
    // Adjust by touch offset to keep the button under the finger
    CGPoint newCenter = CGPointMake(location.x - self.touchOffset.x + self.frame.size.width/2,
                                   location.y - self.touchOffset.y + self.frame.size.height/2);
    
    // Keep button within screen bounds with a margin
    CGFloat margin = 10.0;
    newCenter.x = MAX(self.frame.size.width/2 + margin, 
                     MIN(newCenter.x, self.superview.frame.size.width - self.frame.size.width/2 - margin));
    newCenter.y = MAX(self.frame.size.height/2 + margin, 
                     MIN(newCenter.y, self.superview.frame.size.height - self.frame.size.height/2 - margin));
    
    self.center = newCenter;
    
    // Notify controller of movement
    if (self.controller) {
        float percentX = self.center.x / self.superview.frame.size.width;
        float percentY = self.center.y / self.superview.frame.size.height;
        self.controller->SetCustomPosition(percentX, percentY);
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // Restore button size with animation
    [UIView animateWithDuration:0.2 animations:^{
        self.transform = CGAffineTransformIdentity;
        self.glowLayer.opacity = 1.0; // Restore normal glow
    }];
    
    // Check if this was a tap (not a drag)
    UITouch *touch = [touches anyObject];
    CGPoint initialPoint = [touch locationInView:self];
    CGPoint finalPoint = [touch locationInView:self];
    
    // If touch didn't move much, consider it a tap
    if (hypot(finalPoint.x - initialPoint.x, finalPoint.y - initialPoint.y) < 10) {
        if (self.controller) {
            // If quick action menu is visible, hide it
            if (self.quickActionMenu) {
                [self hideQuickActionMenu];
            } else {
                // Trigger tap action and pulse effect
                [self triggerPulseEffect];
                self.controller->performTapAction();
            }
        }
    } else {
        // This was a drag, snap to nearest edge
        [self snapToNearestEdge];
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [UIView animateWithDuration:0.1 animations:^{
        self.transform = CGAffineTransformIdentity;
        self.glowLayer.opacity = 1.0; // Restore normal glow
    }];
}

- (void)snapToNearestEdge {
    CGRect bounds = self.superview.bounds;
    CGPoint center = self.center;
    
    // Calculate distances to each edge
    CGFloat distToLeft = center.x;
    CGFloat distToRight = bounds.size.width - center.x;
    CGFloat distToTop = center.y;
    CGFloat distToBottom = bounds.size.height - center.y;
    
    // Find the minimum distance
    CGFloat minDist = MIN(MIN(distToLeft, distToRight), MIN(distToTop, distToBottom));
    
    // Determine which edge is closest
    iOS::FloatingButtonController::Position newPosition;
    
    if (minDist == distToLeft) {
        // Snap to left edge
        if (center.y < bounds.size.height / 2) {
            newPosition = iOS::FloatingButtonController::Position::TopLeft;
        } else {
            newPosition = iOS::FloatingButtonController::Position::BottomLeft;
        }
    } else if (minDist == distToRight) {
        // Snap to right edge
        if (center.y < bounds.size.height / 2) {
            newPosition = iOS::FloatingButtonController::Position::TopRight;
        } else {
            newPosition = iOS::FloatingButtonController::Position::BottomRight;
        }
    } else if (minDist == distToTop) {
        // Snap to top edge
        if (center.x < bounds.size.width / 2) {
            newPosition = iOS::FloatingButtonController::Position::TopLeft;
        } else {
            newPosition = iOS::FloatingButtonController::Position::TopRight;
        }
    } else {
        // Snap to bottom edge
        if (center.x < bounds.size.width / 2) {
            newPosition = iOS::FloatingButtonController::Position::BottomLeft;
        } else {
            newPosition = iOS::FloatingButtonController::Position::BottomRight;
        }
    }
    
    // Notify controller to update position with animation
    if (self.controller) {
        // Trigger a small pulse
        [self triggerPulseEffect];
        self.controller->SetPosition(newPosition);
    }
}

@end

namespace iOS {
    // Constructor
    FloatingButtonController::FloatingButtonController(Position initialPosition, float size, float opacity)
        : m_buttonView(nullptr), m_isVisible(false), m_position(initialPosition),
          m_opacity(opacity), m_customX(0.0f), m_customY(0.0f), m_size(size),
          m_tapCallback(nullptr), m_isBeingDragged(false) {
        
        // Create the button
        CGRect frame = CGRectMake(0, 0, m_size, m_size);
        FloatingButton* button = [[FloatingButton alloc] initWithFrame:frame];
        button.controller = this;
        button.alpha = m_opacity;
        
        // Get the key window
        UIWindow* keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            NSSet<UIScene *> *connectedScenes = [[UIApplication sharedApplication] connectedScenes];
            NSArray<UIScene *> *scenes = [connectedScenes allObjects];
            for (UIScene *scene in scenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    for (UIWindow *window in windowScene.windows) {
                        if (window.isKeyWindow) {
                            keyWindow = window;
                            break;
                        }
                    }
                }
            }
        } else {
            keyWindow = [UIApplication sharedApplication].keyWindow;
        }
        
        if (keyWindow) {
            [keyWindow addSubview:button];
            
            // Add tap gesture recognizer
            UITapGestureRecognizer* tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:button action:@selector(handleTap:)];
            [button addGestureRecognizer:tapGesture];
            
            // Store the button and apply initial position
            #if __has_feature(objc_arc)
            // In ARC mode, use CFBridgingRetain to transfer ownership to C++
            // Cast needed to convert const void* to void* (safe in this case since we own the object)
            m_buttonView = (void*)CFBridgingRetain(button);
            #else
            // In non-ARC mode, use manual retain
            m_buttonView = (void*)button;
            [button retain]; // Explicitly retain the button since we're not using ARC
            #endif
            UpdateButtonPosition();
            
            // Initially hidden
            button.hidden = YES;
            
            // Load previous settings (may show the button if it was visible before)
            LoadPosition();
        }
    }
    
    // Destructor
    FloatingButtonController::~FloatingButtonController() {
        if (m_buttonView) {
            #if __has_feature(objc_arc)
            // In ARC mode, use CFBridgingRelease to transfer ownership back to ARC
            FloatingButton* button = (__bridge_transfer FloatingButton*)m_buttonView;
            [button removeFromSuperview];
            // No need for explicit release in ARC
            #else
            // In non-ARC mode, use manual release
            FloatingButton* button = (FloatingButton*)m_buttonView;
            [button removeFromSuperview];
            [button release]; // Explicitly release since we're manually retaining
            #endif
            m_buttonView = nullptr;
        }
    }
    
    // Update button position based on current settings
    void FloatingButtonController::UpdateButtonPosition() {
        if (!m_buttonView) return;
        
        FloatingButton* button = (__bridge FloatingButton*)m_buttonView;
        UIView* superView = button.superview;
        if (!superView) return;
        
        CGRect bounds = superView.bounds;
        CGFloat safeAreaTop = 0, safeAreaBottom = 0, safeAreaLeft = 0, safeAreaRight = 0;
        
        // Account for safe area (notch, etc.)
        if (@available(iOS 11.0, *)) {
            UIEdgeInsets safeArea = superView.safeAreaInsets;
            safeAreaTop = safeArea.top;
            safeAreaBottom = safeArea.bottom;
            safeAreaLeft = safeArea.left;
            safeAreaRight = safeArea.right;
        }
        
        // Calculate the new position
        CGPoint newCenter;
        CGFloat margin = 15.0f; // Margin from edges
        
        switch (m_position) {
            case Position::TopLeft:
                newCenter = CGPointMake(safeAreaLeft + button.frame.size.width/2 + margin,
                                       safeAreaTop + button.frame.size.height/2 + margin);
                break;
                
            case Position::TopRight:
                newCenter = CGPointMake(bounds.size.width - safeAreaRight - button.frame.size.width/2 - margin,
                                       safeAreaTop + button.frame.size.height/2 + margin);
                break;
                
            case Position::BottomLeft:
                newCenter = CGPointMake(safeAreaLeft + button.frame.size.width/2 + margin,
                                       bounds.size.height - safeAreaBottom - button.frame.size.height/2 - margin);
                break;
                
            case Position::BottomRight:
                newCenter = CGPointMake(bounds.size.width - safeAreaRight - button.frame.size.width/2 - margin,
                                       bounds.size.height - safeAreaBottom - button.frame.size.height/2 - margin);
                break;
                
            case Position::Custom:
                newCenter = CGPointMake(m_customX * bounds.size.width,
                                       m_customY * bounds.size.height);
                break;
        }
        
        // Animate the move
        [UIView animateWithDuration:0.4
                              delay:0
             usingSpringWithDamping:0.7
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             button.center = newCenter;
                         }
                         completion:nil];
        
        // Save position for future sessions
        SavePosition();
    }
    
    // Save position to user defaults
    void FloatingButtonController::SavePosition() {
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        
        // Save position enum
        [defaults setInteger:(NSInteger)m_position forKey:@"FloatingButton_Position"];
        
        // Save custom position
        [defaults setFloat:m_customX forKey:@"FloatingButton_CustomX"];
        [defaults setFloat:m_customY forKey:@"FloatingButton_CustomY"];
        
        // Save other settings
        [defaults setFloat:m_opacity forKey:@"FloatingButton_Opacity"];
        [defaults setFloat:m_size forKey:@"FloatingButton_Size"];
        [defaults setBool:m_isVisible forKey:@"FloatingButton_Visible"];
        
        [defaults synchronize];
    }
    
    // Load position from user defaults
    void FloatingButtonController::LoadPosition() {
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        
        // Load position if available
        if ([defaults objectForKey:@"FloatingButton_Position"]) {
            m_position = (Position)[defaults integerForKey:@"FloatingButton_Position"];
        }
        
        // Load custom position
        if ([defaults objectForKey:@"FloatingButton_CustomX"]) {
            m_customX = [defaults floatForKey:@"FloatingButton_CustomX"];
        }
        
        if ([defaults objectForKey:@"FloatingButton_CustomY"]) {
            m_customY = [defaults floatForKey:@"FloatingButton_CustomY"];
        }
        
        // Load other settings
        if ([defaults objectForKey:@"FloatingButton_Opacity"]) {
            m_opacity = [defaults floatForKey:@"FloatingButton_Opacity"];
        }
        
        if ([defaults objectForKey:@"FloatingButton_Size"]) {
            m_size = [defaults floatForKey:@"FloatingButton_Size"];
        }
        
        // Load visibility state - if it was visible before, show it
        if ([defaults objectForKey:@"FloatingButton_Visible"]) {
            bool wasVisible = [defaults boolForKey:@"FloatingButton_Visible"];
            if (wasVisible) {
                Show();
            }
        }
        
        // Apply loaded settings
        if (m_buttonView) {
            FloatingButton* button = (__bridge FloatingButton*)m_buttonView;
            button.alpha = m_opacity;
            
            // Resize button
            CGRect frame = button.frame;
            frame.size.width = m_size;
            frame.size.height = m_size;
            button.frame = frame;
            button.layer.cornerRadius = m_size / 2.0;
            
            // Update LED effect sizes
            [button setupLEDEffects];
            
            UpdateButtonPosition();
        }
    }
    
    // Show the button
    void FloatingButtonController::Show() {
        if (!m_buttonView) return;
        
        FloatingButton* button = (__bridge FloatingButton*)m_buttonView;
        
        // Only animate if currently hidden
        if (button.hidden) {
            button.hidden = NO;
            button.transform = CGAffineTransformMakeScale(0.1, 0.1);
            button.alpha = 0;
            
            [UIView animateWithDuration:0.4
                                  delay:0
                 usingSpringWithDamping:0.6
                  initialSpringVelocity:0.5
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                                 button.transform = CGAffineTransformIdentity;
                                 button.alpha = m_opacity;
                             }
                             completion:^(BOOL finished) {
                                 [button triggerPulseEffect];
                             }];
        }
        
        m_isVisible = true;
        SavePosition();
    }
    
    // Hide the button
    void FloatingButtonController::Hide() {
        if (!m_buttonView) return;
        
        FloatingButton* button = (__bridge FloatingButton*)m_buttonView;
        
        // Hide any quick action menu
        [button hideQuickActionMenu];
        
        // Only animate if currently visible
        if (!button.hidden) {
            [UIView animateWithDuration:0.3
                             animations:^{
                                 button.transform = CGAffineTransformMakeScale(0.1, 0.1);
                                 button.alpha = 0;
                             }
                             completion:^(BOOL finished) {
                                 button.hidden = YES;
                                 button.transform = CGAffineTransformIdentity;
                             }];
        }
        
        m_isVisible = false;
        SavePosition();
    }
    
    // Toggle visibility
    bool FloatingButtonController::Toggle() {
        if (m_isVisible) {
            Hide();
        } else {
            Show();
        }
        return m_isVisible;
    }
    
    // Set visibility
    void FloatingButtonController::SetVisible(bool visible) {
        if (visible) {
            Show();
        } else {
            Hide();
        }
    }
    
    // Check visibility
    bool FloatingButtonController::IsVisible() const {
        return m_isVisible;
    }
    
    // Set position
    void FloatingButtonController::SetPosition(Position position) {
        m_position = position;
        UpdateButtonPosition();
    }
    
    // Set custom position
    void FloatingButtonController::SetCustomPosition(float x, float y) {
        m_customX = std::max(0.0f, std::min(1.0f, x));
        m_customY = std::max(0.0f, std::min(1.0f, y));
        m_position = Position::Custom;
        UpdateButtonPosition();
    }
    
    // Get position
    FloatingButtonController::Position FloatingButtonController::GetPosition() const {
        return m_position;
    }
    
    // Get custom X
    float FloatingButtonController::GetCustomX() const {
        return m_customX;
    }
    
    // Get custom Y
    float FloatingButtonController::GetCustomY() const {
        return m_customY;
    }
    
    // Set opacity
    void FloatingButtonController::SetOpacity(float opacity) {
        m_opacity = std::max(0.0f, std::min(1.0f, opacity));
        
        if (m_buttonView) {
            FloatingButton* button = (__bridge FloatingButton*)m_buttonView;
            button.alpha = m_opacity;
        }
        
        SavePosition();
    }
    
    // Implementation of performTapAction
    void FloatingButtonController::performTapAction() {
        if (m_tapCallback) {
            m_tapCallback();
        }
    }
    
    // Get opacity
    float FloatingButtonController::GetOpacity() const {
        return m_opacity;
    }
    
    // Set LED color and intensity
    void FloatingButtonController::SetLEDEffect(UIColor* color, float intensity) {
        if (m_buttonView) {
            FloatingButton* button = (__bridge FloatingButton*)m_buttonView;
            [button updateLEDColor:color intensity:intensity];
        }
    }
    
    // Trigger a pulse effect
    void FloatingButtonController::TriggerPulseEffect() {
        if (m_buttonView) {
            FloatingButton* button = (__bridge FloatingButton*)m_buttonView;
            [button triggerPulseEffect];
        }
    }
    
    // Set button uses haptic feedback
    void FloatingButtonController::SetUseHapticFeedback(bool enabled) {
        if (m_buttonView) {
            FloatingButton* button = (__bridge FloatingButton*)m_buttonView;
            button.usesHapticFeedback = enabled;
        }
    }
    
    // Set size
    void FloatingButtonController::SetSize(float size) {
        m_size = std::max(20.0f, std::min(100.0f, size));
        
        if (m_buttonView) {
            FloatingButton* button = (__bridge FloatingButton*)m_buttonView;
            
            CGRect frame = button.frame;
            frame.size.width = m_size;
            frame.size.height = m_size;
            button.frame = frame;
            button.layer.cornerRadius = m_size / 2.0;
            
            // Update LED effects for new size
            [button setupLEDEffects];
            
            UpdateButtonPosition();
        }
        
        SavePosition();
    }
    
    // Get size
    float FloatingButtonController::GetSize() const {
        return m_size;
    }
    
    // Set tap callback
    void FloatingButtonController::SetTapCallback(TapCallback callback) {
        m_tapCallback = callback;
    }
    
    // Enable/disable dragging
    void FloatingButtonController::SetDraggable(bool enabled) {
        if (m_buttonView) {
            FloatingButton* button = (__bridge FloatingButton*)m_buttonView;
            button.draggable = enabled;
        }
    }
    
    // Check if being dragged
    bool FloatingButtonController::IsBeingDragged() const {
        return m_isBeingDragged;
    }
}

// Objective-C category extension to handle the tap gesture
@implementation FloatingButton (TapGesture)

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    if (self.controller && self.controller->IsVisible()) {
        // If quick action menu is visible, hide it
        if (self.quickActionMenu) {
            [self hideQuickActionMenu];
            return;
        }
        
        // Apply haptic feedback
        if (self.usesHapticFeedback) {
            applyHapticFeedback(UIImpactFeedbackStyleMedium);
        }
        
        // Perform tap animation with enhanced visual feedback
        [UIView animateWithDuration:0.15
                         animations:^{
                             self.transform = CGAffineTransformMakeScale(0.9, 0.9);
                             self.glowLayer.opacity = 1.5; // Increase glow on tap
                         }
                         completion:^(BOOL finished) {
                             [UIView animateWithDuration:0.15
                                              animations:^{
                                                  self.transform = CGAffineTransformIdentity;
                                                  self.glowLayer.opacity = 1.0;
                                              }
                                              completion:^(BOOL finished) {
                                                  // Trigger pulse effect
                                                  [self triggerPulseEffect];
                                                  
                                                  // Call the tap callback
                                                  if (self.controller) {
                                                      self.controller->performTapAction();
                                                  }
                                              }];
                         }];
    }
}

@end

// Helper functions implementation

static CALayer* createLEDGlowLayer(CGRect frame, UIColor* color, CGFloat intensity) {
    CALayer* glowLayer = [CALayer layer];
    glowLayer.frame = frame;
    glowLayer.cornerRadius = frame.size.width / 2.0;
    glowLayer.backgroundColor = [UIColor clearColor].CGColor;
    
    // Create a subtle border
    glowLayer.borderWidth = 2.0;
    glowLayer.borderColor = color.CGColor;
    
    // Add glow using shadow
    glowLayer.shadowColor = color.CGColor;
    glowLayer.shadowOffset = CGSizeMake(0, 0);
    glowLayer.shadowRadius = 10.0 * intensity;
    glowLayer.shadowOpacity = 0.8 * intensity;
    
    return glowLayer;
}

static CABasicAnimation* createPulseAnimation(CGFloat duration, CGFloat intensity) {
    CABasicAnimation* pulseAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulseAnimation.fromValue = @(1.0);
    pulseAnimation.toValue = @(1.3);
    pulseAnimation.duration = duration * 0.5;
    pulseAnimation.autoreverses = YES;
    pulseAnimation.repeatCount = 1;
    pulseAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    
    return pulseAnimation;
}

static void applyHapticFeedback(UIImpactFeedbackStyle style) {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:style];
        [generator prepare];
        [generator impactOccurred];
    }
}
