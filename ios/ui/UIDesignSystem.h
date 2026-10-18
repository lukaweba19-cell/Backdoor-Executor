
#pragma once
#include "../../objc_isolation.h"

#include <string>
#include <vector>
#include <functional>
#include <unordered_map>

namespace iOS {
namespace UI {

    /**
     * @class UIDesignSystem
     * @brief Defines the visual language and effects for the executor UI
     * 
     * This class implements a consistent design system with LED effects, animations,
     * and interactive elements that make the UI feel alive and responsive while
     * maintaining memory efficiency across iOS 15-18+ devices.
     */
    class UIDesignSystem {
    public:
        // Color palette structure
        struct ColorPalette {
            UIColor* m_primary;            // Primary brand color
            UIColor* m_secondary;          // Secondary brand color
            UIColor* m_accent;             // Accent color for highlights
            UIColor* m_background;         // Background color
            UIColor* m_cardBackground;     // Card background color
            UIColor* m_text;               // Primary text color
            UIColor* m_textSecondary;      // Secondary text color
            UIColor* m_success;            // Success color
            UIColor* m_warning;            // Warning color
            UIColor* m_error;              // Error color
            UIColor* m_ledGlow;            // LED glow color
            std::unordered_map<std::string, UIColor*> m_additionalColors; // Additional colors
            
            ColorPalette();
            ~ColorPalette();
        };
        
        // Animation preset structure
        struct AnimationPreset {
            std::string m_name;            // Preset name
            float m_duration;              // Animation duration
            float m_delay;                 // Animation delay
            std::string m_curveType;       // Animation curve type
            float m_springDamping;         // Spring damping (for spring animations)
            float m_initialVelocity;       // Initial velocity (for spring animations)
            std::string m_keyPath;         // Animation key path
            bool m_autoreverse;            // Whether animation should autoreverse
            int m_repeatCount;             // Repeat count (0 = no repeat)
            
            AnimationPreset();
        };
        
        // LED effect structure
        struct LEDEffect {
            std::string m_type;            // Effect type (pulse, glow, breathe, etc.)
            UIColor* m_color;              // Effect color
            float m_intensity;             // Effect intensity
            float m_radius;                // Effect radius
            float m_speed;                 // Effect speed
            bool m_reactive;               // Whether effect reacts to user interaction
            std::string m_pattern;         // Effect pattern (solid, dashed, etc.)
            float m_colorVariation;        // Color variation amount
            
            LEDEffect();
            ~LEDEffect();
        };
        
        // Text style structure
        struct TextStyle {
            std::string m_fontName;        // Font name
            float m_fontSize;              // Font size
            float m_lineHeight;            // Line height
            float m_letterSpacing;         // Letter spacing
            UIColor* m_textColor;          // Text color
            bool m_isBold;                 // Is bold
            bool m_isItalic;               // Is italic
            bool m_useMonospace;           // Use monospace font
            bool m_useDynamicType;         // Use dynamic type for accessibility
            
            TextStyle();
            ~TextStyle();
        };
        
        // Effect callback type
        using EffectCreatedCallback = std::function<void(void*)>;
        
    private:
        // Member variables with consistent m_ prefix
        std::unordered_map<std::string, ColorPalette> m_colorSchemes;  // Color schemes
        std::unordered_map<std::string, AnimationPreset> m_animations; // Animation presets
        std::unordered_map<std::string, LEDEffect> m_ledEffects;       // LED effects
        std::unordered_map<std::string, TextStyle> m_textStyles;       // Text styles
        void* m_effectsEngine;             // Opaque pointer to effects engine
        void* m_ledFilterCache;            // Opaque pointer to LED filter cache
        void* m_animationController;       // Opaque pointer to animation controller
        std::string m_activeColorScheme;   // Active color scheme
        bool m_useHaptics;                 // Use haptic feedback
        bool m_useReducedMotion;           // Use reduced motion for accessibility
        bool m_useReducedTransparency;     // Use reduced transparency for accessibility
        bool m_optimizeForMemory;          // Optimize visual effects for memory
        float m_globalEffectIntensity;     // Global effect intensity
        float m_globalAnimationSpeed;      // Global animation speed multiplier
        int m_maxConcurrentEffects;        // Maximum concurrent effects
        EffectCreatedCallback m_effectCreatedCallback; // Effect created callback
        
        // Private methods
        void InitializeDefaultStyles();
        void SetupColorSchemes();
        void SetupAnimationPresets();
        void SetupLEDEffects();
        void SetupTextStyles();
        void* CreateCAGradientLayer(const LEDEffect& effect);
        void* CreateGlowLayer(UIColor* color, float intensity, float radius);
        void* CreatePulseAnimation(float duration, float intensity);
        void* ApplyShadowWithLEDEffect(void* view, const LEDEffect& effect);
        void CacheCommonEffects();
        void OptimizeEffectsForMemory();
        void CleanupUnusedEffects();
        void UpdateDynamicEffects();
        UIColor* AdjustColorForScheme(UIColor* color, const std::string& scheme);
        
    public:
        /**
         * @brief Constructor
         */
        UIDesignSystem();
        
        /**
         * @brief Destructor
         */
        ~UIDesignSystem();
        
        /**
         * @brief Initialize the design system
         * @return True if initialization succeeded, false otherwise
         */
        bool Initialize();
        
        /**
         * @brief Get the shared instance
         * @return Shared instance
         */
        static UIDesignSystem& GetSharedInstance();
        
        /**
         * @brief Apply LED effect to a view
         * @param view Opaque pointer to view
         * @param effectName Name of effect to apply
         * @return Opaque pointer to created effect
         */
        void* ApplyLEDEffect(void* view, const std::string& effectName);
        
        /**
         * @brief Apply custom LED effect to a view
         * @param view Opaque pointer to view
         * @param effect LED effect configuration
         * @return Opaque pointer to created effect
         */
        void* ApplyCustomLEDEffect(void* view, const LEDEffect& effect);
        
        /**
         * @brief Remove LED effect from a view
         * @param view Opaque pointer to view
         */
        void RemoveLEDEffect(void* view);
        
        /**
         * @brief Pulse a LED effect
         * @param effectLayer Opaque pointer to effect layer
         * @param duration Pulse duration
         * @param intensity Pulse intensity
         */
        void PulseLEDEffect(void* effectLayer, float duration, float intensity);
        
        /**
         * @brief Apply an animation preset to a view
         * @param view Opaque pointer to view
         * @param presetName Name of animation preset
         * @return Opaque pointer to created animation
         */
        void* ApplyAnimation(void* view, const std::string& presetName);
        
        /**
         * @brief Apply text style to a label
         * @param label Opaque pointer to label
         * @param styleName Name of text style
         */
        void ApplyTextStyle(void* label, const std::string& styleName);
        
        /**
         * @brief Apply color scheme to a view
         * @param view Opaque pointer to view
         * @param schemeName Name of color scheme
         */
        void ApplyColorScheme(void* view, const std::string& schemeName);
        
        /**
         * @brief Get color from current scheme
         * @param colorName Name of color
         * @return Color instance
         */
        UIColor* GetColor(const std::string& colorName) const;
        
        /**
         * @brief Get color palette for a scheme
         * @param schemeName Name of color scheme
         * @return Color palette
         */
        ColorPalette GetColorPalette(const std::string& schemeName) const;
        
        /**
         * @brief Get animation preset
         * @param presetName Name of animation preset
         * @return Animation preset
         */
        AnimationPreset GetAnimationPreset(const std::string& presetName) const;
        
        /**
         * @brief Get LED effect
         * @param effectName Name of LED effect
         * @return LED effect
         */
        LEDEffect GetLEDEffect(const std::string& effectName) const;
        
        /**
         * @brief Get text style
         * @param styleName Name of text style
         * @return Text style
         */
        TextStyle GetTextStyle(const std::string& styleName) const;
        
        /**
         * @brief Set the active color scheme
         * @param schemeName Name of color scheme
         */
        void SetActiveColorScheme(const std::string& schemeName);
        
        /**
         * @brief Get the active color scheme
         * @return Active color scheme name
         */
        std::string GetActiveColorScheme() const;
        
        /**
         * @brief Create a button with LED effect
         * @param title Button title
         * @param effectName Name of LED effect
         * @return Opaque pointer to created button
         */
        void* CreateButtonWithLEDEffect(const std::string& title, const std::string& effectName);
        
        /**
         * @brief Add glowing border to a view
         * @param view Opaque pointer to view
         * @param color Border color
         * @param width Border width
         * @param intensity Glow intensity
         * @return Opaque pointer to created border layer
         */
        void* AddGlowingBorder(void* view, UIColor* color, float width, float intensity);
        
        /**
         * @brief Create interactive effect for a view
         * @param view Opaque pointer to view
         * @param touchDownEffectName Effect to apply on touch down
         * @param touchUpEffectName Effect to apply on touch up
         */
        void AddInteractiveEffect(void* view, const std::string& touchDownEffectName, 
                                 const std::string& touchUpEffectName);
        
        /**
         * @brief Set global effect intensity
         * @param intensity Global effect intensity (0.0 - 1.0)
         */
        void SetGlobalEffectIntensity(float intensity);
        
        /**
         * @brief Get global effect intensity
         * @return Global effect intensity
         */
        float GetGlobalEffectIntensity() const;
        
        /**
         * @brief Set global animation speed
         * @param speed Global animation speed multiplier
         */
        void SetGlobalAnimationSpeed(float speed);
        
        /**
         * @brief Get global animation speed
         * @return Global animation speed multiplier
         */
        float GetGlobalAnimationSpeed() const;
        
        /**
         * @brief Enable or disable haptic feedback
         * @param enable Whether to enable haptic feedback
         */
        void SetUseHaptics(bool enable);
        
        /**
         * @brief Check if haptic feedback is enabled
         * @return True if haptic feedback is enabled, false otherwise
         */
        bool GetUseHaptics() const;
        
        /**
         * @brief Enable or disable reduced motion
         * @param enable Whether to enable reduced motion
         */
        void SetUseReducedMotion(bool enable);
        
        /**
         * @brief Check if reduced motion is enabled
         * @return True if reduced motion is enabled, false otherwise
         */
        bool GetUseReducedMotion() const;
        
        /**
         * @brief Enable or disable reduced transparency
         * @param enable Whether to enable reduced transparency
         */
        void SetUseReducedTransparency(bool enable);
        
        /**
         * @brief Check if reduced transparency is enabled
         * @return True if reduced transparency is enabled, false otherwise
         */
        bool GetUseReducedTransparency() const;
        
        /**
         * @brief Enable or disable memory optimization
         * @param enable Whether to optimize for memory
         */
        void SetOptimizeForMemory(bool enable);
        
        /**
         * @brief Check if memory optimization is enabled
         * @return True if memory optimization is enabled, false otherwise
         */
        bool GetOptimizeForMemory() const;
        
        /**
         * @brief Set maximum concurrent effects
         * @param max Maximum number of concurrent effects
         */
        void SetMaxConcurrentEffects(int max);
        
        /**
         * @brief Get maximum concurrent effects
         * @return Maximum number of concurrent effects
         */
        int GetMaxConcurrentEffects() const;
        
        /**
         * @brief Set effect created callback
         * @param callback Function to call when an effect is created
         */
        void SetEffectCreatedCallback(const EffectCreatedCallback& callback);
        
        /**
         * @brief Get memory usage
         * @return Memory usage in bytes
         */
        uint64_t GetMemoryUsage() const;
        
        /**
         * @brief Generate default iOS 15-18 compatible schemes
         * @return Map of scheme names to color palettes
         */
        static std::unordered_map<std::string, ColorPalette> GenerateDefaultColorSchemes();
        
        /**
         * @brief Generate default LED effects
         * @return Map of effect names to LED effects
         */
        static std::unordered_map<std::string, LEDEffect> GenerateDefaultLEDEffects();
    };

} // namespace UI
} // namespace iOS
