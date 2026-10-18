#pragma once
#include "objc_isolation.h"

#include <string>
#include <map>
#include <vector>
#include <sstream>
#include <cstdint>

namespace iOS {
namespace AIFeatures {

/**
 * @class AIConfig
 * @brief Configuration for AI system
 * 
 * This class holds configuration options for the AI system, including
 * paths, model settings, learning modes, and other parameters. It provides
 * a consistent interface for accessing and modifying configuration values.
 * 
 * This implementation focuses on local-only AI models that are created and trained
 * on the device, without relying on external API services.
 */
class AIConfig {
public:
    /**
     * @brief Learning mode enumeration
     */
    enum class LearningMode {
        Continuous, // Learn continuously during execution
        OnDemand,   // Learn only when requested
        Scheduled,  // Learn on a schedule
        Disabled    // Do not learn
    };
    
    /**
     * @brief Model improvement mode enumeration
     */
    enum class ModelImprovement {
        None,       // No model improvement
        Local       // Local model improvement only
    };
    
    /**
     * @brief Vulnerability detection level enumeration
     */
    enum class DetectionLevel {
        Basic,      // Basic detection level
        Standard,   // Standard detection level
        Thorough,   // Thorough detection level
        Exhaustive  // Exhaustive detection level
    };

    /**
     * @brief Operation mode enumeration
     */
    enum class OperationMode {
        Standard,         // Standard operation
        HighPerformance,  // High performance mode
        HighQuality,      // High quality mode
        LowMemory         // Low memory usage mode
    };

    /**
     * @brief Online mode enumeration
     * Note: Offline modes removed — online only
     */
    enum class OnlineMode {
        Auto,            // Automatically choose based on connectivity
        PreferOnline,    // Prefer online mode
        OnlineOnly       // Only use online mode
        OnlineOnly       // Only use online mode
    };

    /**
     * @brief Model quality enumeration
     */
    enum class ModelQuality {
        Low,       // Low quality model (faster, less accurate)
        Medium,    // Medium quality model (balance of speed and accuracy)
        High       // High quality model (slower, more accurate)
    };
    
private:
    // Singleton instance
    static AIConfig* s_instance;
    
    // Configuration options
    std::map<std::string, std::string> m_options;
    
    // Helper to get option with default value
    std::string GetOption(const std::string& key, const std::string& defaultValue) const {
        auto it = m_options.find(key);
        return (it != m_options.end()) ? it->second : defaultValue;
    }
    
    // Helper to set option
    void SetOption(const std::string& key, const std::string& value) {
        m_options[key] = value;
    }
    
    // Convert learning mode to string
    std::string LearningModeToString(LearningMode mode) const {
        switch (mode) {
            case LearningMode::Continuous:
                return "continuous";
            case LearningMode::OnDemand:
                return "on_demand";
            case LearningMode::Scheduled:
                return "scheduled";
            case LearningMode::Disabled:
                return "disabled";
            default:
                return "continuous";
        }
    }
    
    // Convert string to learning mode
    LearningMode StringToLearningMode(const std::string& str) const {
        if (str == "continuous") {
            return LearningMode::Continuous;
        } else if (str == "on_demand") {
            return LearningMode::OnDemand;
        } else if (str == "scheduled") {
            return LearningMode::Scheduled;
        } else if (str == "disabled") {
            return LearningMode::Disabled;
        } else {
            return LearningMode::Continuous;
        }
    }
    
    // Convert model improvement to string
    std::string ModelImprovementToString(ModelImprovement mode) const {
        switch (mode) {
            case ModelImprovement::None:
                return "none";
            case ModelImprovement::Local:
                return "local";
            default:
                return "local";
        }
    }
    
    // Convert string to model improvement
    ModelImprovement StringToModelImprovement(const std::string& str) const {
        if (str == "none") {
            return ModelImprovement::None;
        } else {
            return ModelImprovement::Local;
        }
    }
    
public:
    /**
     * @brief Constructor
     */
    AIConfig();
    
    /**
     * @brief Get shared instance (singleton)
     * @return Shared instance
     */
    static AIConfig& GetSharedInstance();
    
    /**
     * @brief Initialize with defaults
     * @return True if initialization succeeded
     */
    bool Initialize();
    
    /**
     * @brief Check if initialized
     * @return True if initialized
     */
    bool IsInitialized() const;
    
    /**
     * @brief Save the configuration
     * @return True if save succeeded
     */
    bool Save() const;
    
    /**
     * @brief Set data path
     * @param path Data path
     */
    void SetDataPath(const std::string& path) {
        SetOption("data_path", path);
    }
    
    /**
     * @brief Get data path
     * @return Data path
     */
    std::string GetDataPath() const {
        return GetOption("data_path", "/var/mobile/Documents/AIData");
    }
    
    /**
     * @brief Set learning mode
     * @param mode Learning mode
     */
    void SetLearningMode(LearningMode mode) {
        SetOption("learning_mode", LearningModeToString(mode));
    }
    
    /**
     * @brief Get learning mode
     * @return Learning mode
     */
    LearningMode GetLearningMode() const {
        std::string modeStr = GetOption("learning_mode", "on_demand");
        return StringToLearningMode(modeStr);
    }
    
    /**
     * @brief Set model improvement mode
     * @param mode Model improvement mode
     */
    void SetModelImprovement(ModelImprovement mode) {
        SetOption("model_improvement", ModelImprovementToString(mode));
    }
    
    /**
     * @brief Get model improvement mode
     * @return Model improvement mode
     */
    ModelImprovement GetModelImprovement() const {
        std::string modeStr = GetOption("model_improvement", "local");
        return StringToModelImprovement(modeStr);
    }
    
    /**
     * @brief Set vulnerability detection level
     * @param level Detection level
     */
    void SetVulnerabilityDetectionLevel(DetectionLevel level) {
        std::string levelStr;
        
        switch (level) {
            case DetectionLevel::Basic:
                levelStr = "basic";
                break;
            case DetectionLevel::Standard:
                levelStr = "standard";
                break;
            case DetectionLevel::Thorough:
                levelStr = "thorough";
                break;
            case DetectionLevel::Exhaustive:
                levelStr = "exhaustive";
                break;
            default:
                levelStr = "standard";
                break;
        }
        
        SetOption("vulnerability_detection_level", levelStr);
    }
    
    /**
     * @brief Get vulnerability detection level
     * @return Detection level
     */
    DetectionLevel GetVulnerabilityDetectionLevel() const {
        std::string levelStr = GetOption("vulnerability_detection_level", "standard");
        
        if (levelStr == "basic") {
            return DetectionLevel::Basic;
        } else if (levelStr == "thorough") {
            return DetectionLevel::Thorough;
        } else if (levelStr == "exhaustive") {
            return DetectionLevel::Exhaustive;
        } else {
            return DetectionLevel::Standard;
        }
    }
    
    /**
     * @brief Set self-improvement enabled
     * @param enabled True to enable
     */
    void SetSelfImprovementEnabled(bool enabled) {
        SetOption("self_improvement_enabled", enabled ? "1" : "0");
    }
    
    /**
     * @brief Get self-improvement enabled
     * @return True if enabled
     */
    bool GetSelfImprovementEnabled() const {
        return GetOption("self_improvement_enabled", "1") == "1";
    }
    
    /**
     * @brief Set offline model generation enabled
     * @param enabled True to enable
     */
    void SetOfflineModelGenerationEnabled(bool enabled) {
        (void)enabled; // Offline removed
        SetOption("offline_model_generation", "0");
    }
    
    /**
     * @brief Get offline model generation enabled
     * @return True if enabled
     */
    bool GetOfflineModelGenerationEnabled() const {
        return false; // Offline removed
    }
    
    /**
     * @brief Set online mode (online-only (offline removed))
     * @param mode Online mode (ignored)
     */
    void SetOnlineMode([[maybe_unused]] OnlineMode mode) {
        // Online-only — offline has been removed
        SetOption("online_mode", "online_only");
    }
    
    /**
     * @brief Get online mode (returns OnlineOnly (offline removed))
     * @return Online mode
     */
    OnlineMode GetOnlineMode() const {
        // Online-only — offline has been removed
        return OnlineMode::OnlineOnly;
    }
    
    /**
     * @brief Set model quality
     * @param quality Model quality
     */
    void SetModelQuality(ModelQuality quality) {
        std::string qualityStr;
        
        switch (quality) {
            case ModelQuality::Low:
                qualityStr = "low";
                break;
            case ModelQuality::Medium:
                qualityStr = "medium";
                break;
            case ModelQuality::High:
                qualityStr = "high";
                break;
            default:
                qualityStr = "medium";
                break;
        }
        
        SetOption("model_quality", qualityStr);
    }
    
    /**
     * @brief Get model quality
     * @return Model quality
     */
    ModelQuality GetModelQuality() const {
        std::string qualityStr = GetOption("model_quality", "medium");
        
        if (qualityStr == "low") {
            return ModelQuality::Low;
        } else if (qualityStr == "high") {
            return ModelQuality::High;
        } else {
            return ModelQuality::Medium;
        }
    }
    
    /**
     * @brief Get API endpoint
     * @return API endpoint URL (empty in this implementation)
     */
    std::string GetAPIEndpoint() const;
    
    /**
     * @brief Set API endpoint
     * @param endpoint API endpoint URL (ignored in this implementation)
     */
    void SetAPIEndpoint(const std::string& endpoint);
    
    /**
     * @brief Get API key
     * @return API key (empty in this implementation)
     */
    std::string GetAPIKey() const;
    
    /**
     * @brief Set API key
     * @param key API key (ignored in this implementation)
     */
    void SetAPIKey(const std::string& key);
    
    /**
     * @brief Get model path
     * @return Path to AI models
     */
    std::string GetModelPath() const;
    
    /**
     * @brief Set model path
     * @param path Path to AI models
     */
    void SetModelPath(const std::string& path);
    
    /**
     * @brief Get whether to encrypt communication
     * @return True if communication should be encrypted (always false in this implementation)
     */
    bool GetEncryptCommunication() const;
    
    /**
     * @brief Set whether to encrypt communication
     * @param encrypt True to encrypt communication (ignored in this implementation)
     */
    void SetEncryptCommunication(bool encrypt);
    
    /**
     * @brief Get maximum memory usage
     * @return Maximum memory usage in bytes
     */
    uint64_t GetMaxMemoryUsage() const;
    
    /**
     * @brief Set maximum memory usage
     * @param maxMemory Maximum memory usage in bytes
     */
    void SetMaxMemoryUsage(uint64_t maxMemory);
    
    /**
     * @brief Check if models should be created on startup
     * @return True if models should be created on startup
     */
    bool ShouldCreateModelsOnStartup() const;
    
    /**
     * @brief Check if models should be rebuilt if needed
     * @return True if models should be rebuilt if needed
     */
    bool ShouldRebuildModelsIfNeeded() const;
    
    /**
     * @brief Get the training data path
     * @return Path to training data
     */
    std::string GetTrainingDataPath() const;
    
    /**
     * @brief Check if training data should be saved
     * @return True if training data should be saved
     */
    bool ShouldSaveTrainingData() const;
    
    /**
     * @brief Get training interval in minutes
     * @return Training interval in minutes
     */
    int GetTrainingIntervalMinutes() const;
    
    /**
     * @brief Get initial model size
     * @return Initial model size (small, medium, large)
     */
    std::string GetInitialModelSize() const;
    
    /**
     * @brief Get max training iterations
     * @return Maximum number of training iterations
     */
    int GetMaxTrainingIterations() const;
    
    /**
     * @brief Get script generation examples count
     * @return Number of script generation examples to keep
     */
    int GetScriptGenerationExamplesCount() const;
    
    /**
     * @brief Get training batch size
     * @return Training batch size
     */
    int GetTrainingBatchSize() const;
    
private:
    /**
     * @brief Ensure all necessary directories exist
     */
    void EnsureDirectoriesExist();
};

} // namespace AIFeatures
} // namespace iOS
