
#include "../ios_compat.h"
#include "UIControllerGameIntegration.h"
#include <iostream>

namespace iOS {
    // Constructor
    UIControllerGameIntegration::UIControllerGameIntegration(
        std::shared_ptr<UIController> uiController,
        std::shared_ptr<GameDetector> gameDetector)
        : m_uiController(uiController),
          m_gameDetector(gameDetector),
          m_autoShowOnGameJoin(true),
          m_autoHideOnGameLeave(true),
          m_showButtonOnlyInGame(true),
          m_callbackId(0) {
    }
    
    // Destructor
    UIControllerGameIntegration::~UIControllerGameIntegration() {
        // Remove callback if registered
        if (m_callbackId != 0 && m_gameDetector) {
            // Removed callback handling
            m_callbackId = 0;
        }
    }
    
    // Initialize the integration
    bool UIControllerGameIntegration::Initialize() {
        // Check if UI controller and game detector are valid
        if (!m_uiController || !m_gameDetector) {
            std::cerr << "UIControllerGameIntegration: Invalid UI controller or game detector" << std::endl;
            return false;
        }
        
        // Register callback for game state changes
        m_gameDetector->SetStateChangeCallback(
            [this](GameState newState) {
                this->OnGameStateChanged(GameState::Unknown, newState);
            });
        
        if (m_callbackId == 0) {
            std::cerr << "UIControllerGameIntegration: Failed to register callback" << std::endl;
            return false;
        }
        
        // Start game detector if not already running
        if (!m_gameDetector->Start()) {
            std::cerr << "UIControllerGameIntegration: Failed to start game detector" << std::endl;
            return false;
        }
        
        // Initialize UI based on current game state
        ForceVisibilityUpdate();
        
        std::cout << "UIControllerGameIntegration: Successfully initialized" << std::endl;
        return true;
    }
    
    // Handle game state changes
    void UIControllerGameIntegration::OnGameStateChanged(
        GameState oldState, GameState newState) {
        
        // Log state change
        std::cout << "UIControllerGameIntegration: Game state changed from " 
                  << static_cast<int>(oldState) << " to " << static_cast<int>(newState) << std::endl;
        
        // Handle state changes
        switch (newState) {
            case GameState::InGame:
                // Player has joined a game
                
                // Update game info in UI
                UpdateUIGameInfo();
                
                // Show executor if auto-show is enabled
                if (m_autoShowOnGameJoin) {
                    // Always show the button in-game
                    m_uiController->SetButtonVisible(true);
                    
                    // Log
                    std::cout << "UIControllerGameIntegration: Automatically showing button on game join" << std::endl;
                }
                break;
                
            case GameState::NotRunning:
                // Player is leaving a game
                
                // Hide executor if auto-hide is enabled
                if (m_autoHideOnGameLeave) {
                    // Hide the main UI
                    m_uiController->Hide();
                    
                    // Don't hide the button yet, wait until fully at menu
                    
                    // Log
                    std::cout << "UIControllerGameIntegration: Hiding main UI on game leave" << std::endl;
                }
                break;
                
            case GameState::InMenu:
                // Player is at menu screens
                
                // Hide button if set to show only in-game
                if (m_showButtonOnlyInGame) {
                    m_uiController->SetButtonVisible(false);
                    
                    // Log
                    std::cout << "UIControllerGameIntegration: Hiding button at menu" << std::endl;
                }
                break;
                
                // Hide everything
                m_uiController->Hide();
                m_uiController->SetButtonVisible(false);
                
                // Log
                std::cout << "UIControllerGameIntegration: Hiding all UI when Roblox not running" << std::endl;
                break;
                
            case GameState::Unknown:
                // Unknown state, don't change anything
                break;
                
            default:
                // No action for other states
                break;
        }
    }
    
    // Update game information in the UI
    void UIControllerGameIntegration::UpdateUIGameInfo() {
        if (!m_uiController || !m_gameDetector) {
            return;
        }
        
        // Get game information
        std::string gameName = m_gameDetector->GetGameName();
        std::string placeId = m_gameDetector->GetPlaceId();
        
        // In a real implementation, we would use this information to update the UI
        // For example, show the game name in a title bar, or provide game-specific script suggestions
        
        // Log for demonstration purposes
        std::cout << "UIControllerGameIntegration: Updated game info - Name: " 
                  << gameName << ", PlaceId: " << placeId << std::endl;
    }
    
    // Set auto-show behavior when joining a game
    void UIControllerGameIntegration::SetAutoShowOnGameJoin(bool enable) {
        m_autoShowOnGameJoin = enable;
        
        // If enabled and already in a game, show the UI
        if (enable && m_gameDetector && m_gameDetector->IsInGame()) {
            m_uiController->SetButtonVisible(true);
        }
    }
    
    // Set auto-hide behavior when leaving a game
    void UIControllerGameIntegration::SetAutoHideOnGameLeave(bool enable) {
        m_autoHideOnGameLeave = enable;
    }
    
    // Set whether the floating button should only be shown in-game
    void UIControllerGameIntegration::SetShowButtonOnlyInGame(bool showOnlyInGame) {
        m_showButtonOnlyInGame = showOnlyInGame;
        
        // Update button visibility based on current game state
        ForceVisibilityUpdate();
    }
    
    // Get auto-show behavior when joining a game
    bool UIControllerGameIntegration::GetAutoShowOnGameJoin() const {
        return m_autoShowOnGameJoin;
    }
    
    // Get auto-hide behavior when leaving a game
    bool UIControllerGameIntegration::GetAutoHideOnGameLeave() const {
        return m_autoHideOnGameLeave;
    }
    
    // Get whether the floating button is only shown in-game
    bool UIControllerGameIntegration::GetShowButtonOnlyInGame() const {
        return m_showButtonOnlyInGame;
    }
    
    // Get the current game state
    GameState UIControllerGameIntegration::GetGameState() const {
        return m_gameDetector ? m_gameDetector->GetCurrentState() : GameState::Unknown;
    }
    
    // Check if player is in a game
    bool UIControllerGameIntegration::IsInGame() const {
        return m_gameDetector ? m_gameDetector->IsInGame() : false;
    }
    
    // Force a UI visibility update based on current game state
    void UIControllerGameIntegration::ForceVisibilityUpdate() {
        if (!m_uiController || !m_gameDetector) {
            return;
        }
        
        // Get current game state
        GameState state = m_gameDetector->GetCurrentState();
        
        // Update button visibility
        switch (state) {
            case GameState::InGame:
                // In game, show button
                m_uiController->SetButtonVisible(true);
                break;
                
            case GameState::InMenu:
            case GameState::Connecting:
            case GameState::NotRunning:
                // At menu or loading or leaving, hide button if set to show only in-game
                m_uiController->SetButtonVisible(!m_showButtonOnlyInGame);
                break;
                
// Removed duplicate case GameState::NotRunning
            case GameState::Unknown:
                m_uiController->SetButtonVisible(false);
                break;
        }
        
        // Log update
        std::cout << "UIControllerGameIntegration: Forced visibility update for state " 
                  << static_cast<int>(state) << std::endl;
    }
}
