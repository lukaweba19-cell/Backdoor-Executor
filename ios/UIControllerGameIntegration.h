#include "objc_isolation.h"


#pragma once

#include "UIController.h"
#include "GameDetector.h"
#include <memory>

namespace iOS {
    /**
     * @class UIControllerGameIntegration
     * @brief Integrates the UIController with GameDetector for game-aware behavior
     * 
     * This class connects the UIController with GameDetector to implement the
     * feature where the executor only appears when the player has joined a game.
     * information to the UI.
     */
    class UIControllerGameIntegration {
    private:
        std::shared_ptr<UIController> m_uiController;
        std::shared_ptr<GameDetector> m_gameDetector;
        bool m_autoShowOnGameJoin;
        bool m_autoHideOnGameLeave;
        bool m_showButtonOnlyInGame;
        size_t m_callbackId;
        
        // Private methods
        void OnGameStateChanged(iOS::GameState oldState, iOS::GameState newState);
        void UpdateUIGameInfo();
        
    public:
        /**
         * @brief Constructor
         * @param uiController The UI controller to integrate with
         * @param gameDetector The game detector to use for game state information
         */
        UIControllerGameIntegration(
            std::shared_ptr<UIController> uiController,
            std::shared_ptr<GameDetector> gameDetector);
        
        /**
         * @brief Destructor
         */
        ~UIControllerGameIntegration();
        
        /**
         * @brief Initialize the integration
         * @return True if initialization succeeded, false otherwise
         */
        bool Initialize();
        
        /**
         * @brief Set auto-show behavior when joining a game
         * @param enable True to automatically show executor on game join, false otherwise
         */
        void SetAutoShowOnGameJoin(bool enable);
        
        /**
         * @brief Set auto-hide behavior when leaving a game
         * @param enable True to automatically hide executor on game leave, false otherwise
         */
        void SetAutoHideOnGameLeave(bool enable);
        
        /**
         * @brief Set whether the floating button should only be shown in-game
         * @param showOnlyInGame True to show button only in-game, false to always show
         */
        void SetShowButtonOnlyInGame(bool showOnlyInGame);
        
        /**
         * @brief Get auto-show behavior when joining a game
         * @return True if executor will automatically show on game join, false otherwise
         */
        bool GetAutoShowOnGameJoin() const;
        
        /**
         * @brief Get auto-hide behavior when leaving a game
         * @return True if executor will automatically hide on game leave, false otherwise
         */
        bool GetAutoHideOnGameLeave() const;
        
        /**
         * @brief Get whether the floating button is only shown in-game
         * @return True if button is only shown in-game, false if always shown
         */
        bool GetShowButtonOnlyInGame() const;
        
        /**
         * @brief Get the current game state
         * @return Current game state
         */
        iOS::GameState GetGameState() const;
        
        /**
         * @brief Check if player is in a game
         * @return True if in a game, false otherwise
         */
        bool IsInGame() const;
        
        /**
         */
        void ForceVisibilityUpdate();
    };
}
