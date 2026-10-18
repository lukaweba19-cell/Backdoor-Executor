
#include "../../objc_isolation.h"
#pragma once

#include <string>
#include <vector>
#include <functional>
#include <memory>
#include <unordered_map>
#include "ScriptEditorViewController.h"

// Forward declare Objective-C classes and types
#if defined(__OBJC__)
#import <CoreGraphics/CGGeometry.h>
@class UIColor;
#else
// For C++ code, define opaque types
#ifndef OBJC_OBJECT_DEFINED
#define OBJC_OBJECT_DEFINED
typedef struct objc_object objc_object;
#endif
typedef objc_object UIColor;
// CGPoint definition for C++
#ifndef CGPOINT_DEFINED
#define CGPOINT_DEFINED
typedef struct {
    float x;
    float y;
} CGPoint;
#endif
#endif

namespace iOS {
namespace UI {

    /**
     * @class ScriptManagementViewController
     * @brief Manages script collection with interactive UI and visual effects
     * 
     * This class implements a modern, memory-efficient script management system
     * with categories, search, interactive animations, and contextual actions.
     * Designed for iOS 15-18+ with LED-like interactive effects.
     */
    class ScriptManagementViewController {
    public:
        // Script category structure
        struct Category {
            std::string m_id;              // Unique identifier
            std::string m_name;            // Category name
            std::string m_iconName;        // SF Symbol icon name
            UIColor* m_color;              // Category color
            bool m_isDefault;              // Is a default category
            int m_order;                   // Display order
            
            Category() : m_color(nullptr), m_isDefault(false), m_order(0) {}
        };
        
        // Script action enumeration
        enum class ScriptAction {
            Edit,
            Execute,
            Rename,
            Delete,
            Favorite,
            Duplicate,
            Export,
            Share,
            MoveToCategory,
            Debug
        };
        
        // View mode enumeration
        enum class ViewMode {
            Grid,
            List,
            Compact
        };
        
        // Management callback types
        using ScriptActionCallback = std::function<void(const ScriptEditorViewController::Script&, ScriptAction)>;
        using CategoryActionCallback = std::function<void(const Category&, bool isCreating)>;
        using SelectionCallback = std::function<void(const ScriptEditorViewController::Script&)>;
        
    private:
        // Member variables with consistent m_ prefix
        void* m_viewController;            // Opaque pointer to UIViewController
        void* m_collectionView;            // Opaque pointer to UICollectionView
        void* m_searchController;          // Opaque pointer to UISearchController
        void* m_tabBar;                    // Opaque pointer to tab bar
        void* m_toolbar;                   // Opaque pointer to toolbar
        void* m_menuController;            // Opaque pointer to menu controller
        void* m_dragDropManager;           // Opaque pointer to drag drop manager
        void* m_emptyStateView;            // Opaque pointer to empty state view
        void* m_effectsManager;            // Opaque pointer to visual effects manager
        std::vector<Category> m_categories; // Script categories
        std::vector<ScriptEditorViewController::Script> m_scripts; // All scripts
        std::vector<ScriptEditorViewController::Script> m_filteredScripts; // Filtered scripts
        std::string m_currentCategoryId;   // Current category ID
        std::string m_searchText;          // Current search text
        ScriptActionCallback m_scriptActionCallback; // Script action callback
        CategoryActionCallback m_categoryActionCallback; // Category action callback
        SelectionCallback m_selectionCallback; // Selection callback
        ViewMode m_viewMode;               // Current view mode
        bool m_isEditing;                  // Is in editing mode
        bool m_isSearching;                // Is searching
        bool m_showScriptDetails;          // Show script details
        bool m_useAnimations;              // Use animations
        int m_columnCount;                 // Column count for grid
        std::unordered_map<std::string, bool> m_expandedCategories; // Expanded state of categories
        std::unordered_map<std::string, void*> m_cellEffects; // Visual effects for cells
        
        // Private methods
        void InitializeUI();
        void SetupCollectionView();
        void SetupSearchController();
        void SetupTabBar();
        void SetupToolbar();
        void SetupMenus();
        void SetupEmptyState();
        void SetupVisualEffects();
        void UpdateViewForMode(ViewMode mode);
        void FilterScripts();
        void ApplySearch(const std::string& searchText);
        void UpdateCollectionView(bool animate);
        void PerformAction(const ScriptEditorViewController::Script& script, ScriptAction action);
        void ShowScriptActionMenu(const ScriptEditorViewController::Script& script, CGPoint position);
        void ShowCategoryActionMenu(const Category& category, CGPoint position);
        void ShowCreateCategoryUI();
        void AnimateCellSelection(void* cell);
        void ApplyLEDEffect(void* view, UIColor* color, float intensity);
        void PulseLEDEffect(void* layer, float duration, float intensity);
        void ApplyBackgroundBlur();
        std::vector<ScriptEditorViewController::Script> GetScriptsInCategory(const std::string& categoryId);
        void ReorderScripts(const std::string& categoryId, const std::vector<std::string>& scriptIds);
        void OptimizeMemory();
        void PreloadCellsForVisibleRegion();
        void ReleaseOffscreenResources();
        
    public:
        /**
         * @brief Constructor
         */
        ScriptManagementViewController();
        
        /**
         * @brief Destructor
         */
        ~ScriptManagementViewController();
        
        /**
         * @brief Initialize the view controller
         * @return True if initialization succeeded, false otherwise
         */
        bool Initialize();
        
        /**
         * @brief Get the native view controller
         * @return Opaque pointer to UIViewController
         */
        void* GetViewController() const;
        
        /**
         * @brief Set script action callback
         * @param callback Function to call for script actions
         */
        void SetScriptActionCallback(const ScriptActionCallback& callback);
        
        /**
         * @brief Set category action callback
         * @param callback Function to call for category actions
         */
        void SetCategoryActionCallback(const CategoryActionCallback& callback);
        
        /**
         * @brief Set selection callback
         * @param callback Function to call when a script is selected
         */
        void SetSelectionCallback(const SelectionCallback& callback);
        
        /**
         * @brief Set the scripts to display
         * @param scripts Scripts to display
         */
        void SetScripts(const std::vector<ScriptEditorViewController::Script>& scripts);
        
        /**
         * @brief Get all scripts
         * @return All scripts
         */
        std::vector<ScriptEditorViewController::Script> GetScripts() const;
        
        /**
         * @brief Set the categories
         * @param categories Categories to use
         */
        void SetCategories(const std::vector<Category>& categories);
        
        /**
         * @brief Get all categories
         * @return All categories
         */
        std::vector<Category> GetCategories() const;
        
        /**
         * @brief Add a script
         * @param script Script to add
         */
        void AddScript(const ScriptEditorViewController::Script& script);
        
        /**
         * @brief Update a script
         * @param script Script to update
         * @return True if update succeeded, false if script not found
         */
        bool UpdateScript(const ScriptEditorViewController::Script& script);
        
        /**
         * @brief Delete a script
         * @param scriptId Script ID to delete
         * @return True if deletion succeeded, false if script not found
         */
        bool DeleteScript(const std::string& scriptId);
        
        /**
         * @brief Add a category
         * @param category Category to add
         */
        void AddCategory(const Category& category);
        
        /**
         * @brief Update a category
         * @param category Category to update
         * @return True if update succeeded, false if category not found
         */
        bool UpdateCategory(const Category& category);
        
        /**
         * @brief Delete a category
         * @param categoryId Category ID to delete
         * @param moveScriptsToCategory Category ID to move scripts to (empty for default)
         * @return True if deletion succeeded, false if category not found
         */
        bool DeleteCategory(const std::string& categoryId, const std::string& moveScriptsToCategory = "");
        
        /**
         * @brief Select a script
         * @param scriptId Script ID to select
         * @return True if selection succeeded, false if script not found
         */
        bool SelectScript(const std::string& scriptId);
        
        /**
         * @brief Select a category
         * @param categoryId Category ID to select
         * @return True if selection succeeded, false if category not found
         */
        bool SelectCategory(const std::string& categoryId);
        
        /**
         * @brief Set view mode
         * @param mode View mode to use
         */
        void SetViewMode(ViewMode mode);
        
        /**
         * @brief Get current view mode
         * @return Current view mode
         */
        ViewMode GetViewMode() const;
        
        /**
         * @brief Set column count for grid mode
         * @param count Number of columns
         */
        void SetColumnCount(int count);
        
        /**
         * @brief Get column count for grid mode
         * @return Column count
         */
        int GetColumnCount() const;
        
        /**
         * @brief Enable or disable animations
         * @param enable Whether to enable animations
         */
        void SetUseAnimations(bool enable);
        
        /**
         * @brief Check if animations are enabled
         * @return True if animations are enabled, false otherwise
         */
        bool GetUseAnimations() const;
        
        /**
         * @brief Enable or disable script details
         * @param enable Whether to show script details
         */
        void SetShowScriptDetails(bool enable);
        
        /**
         * @brief Check if script details are shown
         * @return True if script details are shown, false otherwise
         */
        bool GetShowScriptDetails() const;
        
        /**
         * @brief Search for scripts
         * @param searchText Text to search for
         */
        void Search(const std::string& searchText);
        
        /**
         * @brief Clear search
         */
        void ClearSearch();
        
        /**
         * @brief Enter editing mode
         */
        void EnterEditingMode();
        
        /**
         * @brief Exit editing mode
         */
        void ExitEditingMode();
        
        /**
         * @brief Check if in editing mode
         * @return True if in editing mode, false otherwise
         */
        bool IsEditing() const;
        
        /**
         * @brief Get memory usage
         * @return Memory usage in bytes
         */
        uint64_t GetMemoryUsage() const;
        
        /**
         * @brief Optimize memory usage
         */
        void OptimizeMemoryUsage();
        
        /**
         * @brief Create default categories
         * @return Vector of default categories
         */
        static std::vector<Category> CreateDefaultCategories();
    };

} // namespace UI
} // namespace iOS
