// UIController.mm - Production-grade implementation for iOS
#include "UIController.h"
#include "ui/MainViewController.h"
#include <iostream>
#include <sstream>
#include "filesystem_utils.h"

#ifdef __OBJC__
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

// Forward declarations for Objective-C classes
@class UIControllerMainView;
@class ScriptEditorTextView;
@class ScriptListTableView;
@class ConsoleTextView;
@class SettingsView;

// Main view controller implementation
@interface UIControllerImpl : UIViewController <UITextViewDelegate, UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate>

// UI Elements
@property (nonatomic, strong) UIView *mainView;
@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIButton *minimizeButton;

// Tab buttons
@property (nonatomic, strong) UIButton *editorTabButton;
@property (nonatomic, strong) UIButton *scriptsTabButton;
@property (nonatomic, strong) UIButton *consoleTabButton;
@property (nonatomic, strong) UIButton *settingsTabButton;

// Content views
@property (nonatomic, strong) UIView *editorView;
@property (nonatomic, strong) UITextView *scriptTextView;
@property (nonatomic, strong) UIButton *executeButton;
@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong) UIButton *saveButton;

@property (nonatomic, strong) UIView *scriptsView;
@property (nonatomic, strong) UITableView *scriptsTableView;
@property (nonatomic, strong) UITextField *searchField;

@property (nonatomic, strong) UIView *consoleView;
@property (nonatomic, strong) UITextView *consoleTextView;
@property (nonatomic, strong) UIButton *clearConsoleButton;

@property (nonatomic, strong) UIView *settingsView;
@property (nonatomic, strong) UITableView *settingsTableView;

// Floating button controller
@property (nonatomic, strong) UIButton *floatingButton;
@property (nonatomic, assign) BOOL buttonVisible;

// State
@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, assign) int currentTab;
@property (nonatomic, assign) float opacity;
@property (nonatomic, assign) BOOL isDraggable;
@property (nonatomic, strong) NSString *currentScript;
@property (nonatomic, strong) NSMutableArray *savedScripts;
@property (nonatomic, strong) NSString *consoleText;

// UI Properties
@property (nonatomic, assign) CGPoint lastTouchPoint;
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;

// Callbacks (using blocks to bridge to C++)
@property (nonatomic, copy) BOOL (^executeCallback)(NSString *);
@property (nonatomic, copy) BOOL (^saveScriptCallback)(NSDictionary *);
@property (nonatomic, copy) NSArray * (^loadScriptsCallback)(void);
@property (nonatomic, copy) BOOL (^deleteScriptCallback)(NSString *);

// C++ Main view controller wrapper
@property (nonatomic, strong) id mainViewController;

// Setup UI elements
- (void)setupUI;
- (void)setupMainView;
- (void)setupTopBar;
- (void)setupTabButtons;
- (void)setupEditorView;
- (void)setupScriptsView;
- (void)setupConsoleView;
- (void)setupSettingsView;
- (void)setupFloatingButton;

// Tab management
- (void)switchToTab:(int)tabIndex;
- (void)tabButtonPressed:(UIButton *)sender;

// Action methods
- (void)executeScript;
- (void)clearEditor;
- (void)saveScript;
- (void)closeUI;
- (void)minimizeUI;
- (void)toggleUI;
- (void)floatingButtonPressed;
- (void)clearConsole;
- (void)loadScriptsList;

// Helper methods
- (UIColor *)darkBackgroundColor;
- (UIColor *)lightBackgroundColor;
- (UIColor *)accentColor;
- (UIColor *)buttonColor;
- (UIColor *)textColor;
- (void)appendToConsole:(NSString *)text;
- (void)saveUIState;
- (void)loadUIState;
- (void)applyCornerRadius:(float)radius toView:(UIView *)view;
- (UIButton *)createStyledButton:(NSString *)title color:(UIColor *)color;

@end

// Main implementation
@implementation UIControllerImpl

- (instancetype)init {
    self = [super init];
    if (self) {
        // Initialize state
        _isVisible = NO;
        _currentTab = 0; // Editor tab
        _opacity = 1.0f;
        _isDraggable = YES;
        _currentScript = @"-- Welcome to Roblox Executor\n-- Enter your script here";
        _savedScripts = [NSMutableArray array];
        _consoleText = @"-- Console output will appear here\n";
        _buttonVisible = YES;
        
        // Create a main view controller wrapper
        _mainViewController = [[NSObject alloc] init];
        
        // Initialize UI elements
        [self setupUI];
        
        // Load previously saved state
        [self loadUIState];
    }
    return self;
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, UIScreen.mainScreen.bounds.size.height)];
    self.view.backgroundColor = [UIColor clearColor];
    self.view.userInteractionEnabled = YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Additional setup if needed
}

#pragma mark - UI Setup Methods

- (void)setupUI {
    [self setupMainView];
    [self setupTopBar];
    [self setupTabButtons];
    [self setupEditorView];
    [self setupScriptsView];
    [self setupConsoleView];
    [self setupSettingsView];
    [self setupFloatingButton];
    
    // Initial state
    [self switchToTab:0]; // Editor tab
    self.mainView.hidden = YES; // Start hidden
}

- (void)setupMainView {
    // Main view container
    self.mainView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 700, 400)];
    self.mainView.center = CGPointMake(UIScreen.mainScreen.bounds.size.width/2, UIScreen.mainScreen.bounds.size.height/2);
    self.mainView.backgroundColor = [self darkBackgroundColor];
    self.mainView.layer.cornerRadius = 8.0;
    self.mainView.clipsToBounds = YES;
    self.mainView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.mainView.layer.shadowOffset = CGSizeMake(0, 2);
    self.mainView.layer.shadowOpacity = 0.5;
    self.mainView.layer.shadowRadius = 4.0;
    [self.view addSubview:self.mainView];
    
    // Add drag gesture
    self.panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    self.panGesture.delegate = self;
    [self.mainView addGestureRecognizer:self.panGesture];
}

- (void)setupTopBar {
    // Top bar
    self.topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.mainView.frame.size.width, 36)];
    self.topBar.backgroundColor = [self lightBackgroundColor];
    [self.mainView addSubview:self.topBar];
    
    // Round the top corners of top bar
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:self.topBar.bounds 
                                                   byRoundingCorners:(UIRectCornerTopLeft | UIRectCornerTopRight)
                                                         cornerRadii:CGSizeMake(8.0, 8.0)];
    maskLayer.path = maskPath.CGPath;
    self.topBar.layer.mask = maskLayer;
    
    // Title label
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, 200, 36)];
    self.titleLabel.text = @"Roblox Executor";
    self.titleLabel.textColor = [self textColor];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.topBar addSubview:self.titleLabel];
    
    // Close button
    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.closeButton.frame = CGRectMake(self.mainView.frame.size.width - 36, 0, 36, 36);
    [self.closeButton setTitle:@"×" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:[self textColor] forState:UIControlStateNormal];
    self.closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:24];
    [self.closeButton addTarget:self action:@selector(closeUI) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.closeButton];
    
    // Minimize button
    self.minimizeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.minimizeButton.frame = CGRectMake(self.mainView.frame.size.width - 72, 0, 36, 36);
    [self.minimizeButton setTitle:@"−" forState:UIControlStateNormal];
    [self.minimizeButton setTitleColor:[self textColor] forState:UIControlStateNormal];
    self.minimizeButton.titleLabel.font = [UIFont boldSystemFontOfSize:24];
    [self.minimizeButton addTarget:self action:@selector(minimizeUI) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.minimizeButton];
}

- (void)setupTabButtons {
    float tabWidth = 90;
    float tabHeight = 36;
    float tabStartX = 120;
    
    // Editor tab
    self.editorTabButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.editorTabButton.frame = CGRectMake(tabStartX, 0, tabWidth, tabHeight);
    [self.editorTabButton setTitle:@"Editor" forState:UIControlStateNormal];
    [self.editorTabButton setTitleColor:[self textColor] forState:UIControlStateNormal];
    self.editorTabButton.titleLabel.font = [UIFont systemFontOfSize:14];
    self.editorTabButton.tag = 0;
    [self.editorTabButton addTarget:self action:@selector(tabButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.editorTabButton];
    
    // Scripts tab
    self.scriptsTabButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.scriptsTabButton.frame = CGRectMake(tabStartX + tabWidth, 0, tabWidth, tabHeight);
    [self.scriptsTabButton setTitle:@"Scripts" forState:UIControlStateNormal];
    [self.scriptsTabButton setTitleColor:[self textColor] forState:UIControlStateNormal];
    self.scriptsTabButton.titleLabel.font = [UIFont systemFontOfSize:14];
    self.scriptsTabButton.tag = 1;
    [self.scriptsTabButton addTarget:self action:@selector(tabButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.scriptsTabButton];
    
    // Console tab
    self.consoleTabButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.consoleTabButton.frame = CGRectMake(tabStartX + tabWidth * 2, 0, tabWidth, tabHeight);
    [self.consoleTabButton setTitle:@"Console" forState:UIControlStateNormal];
    [self.consoleTabButton setTitleColor:[self textColor] forState:UIControlStateNormal];
    self.consoleTabButton.titleLabel.font = [UIFont systemFontOfSize:14];
    self.consoleTabButton.tag = 2;
    [self.consoleTabButton addTarget:self action:@selector(tabButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.consoleTabButton];
    
    // Settings tab
    self.settingsTabButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.settingsTabButton.frame = CGRectMake(tabStartX + tabWidth * 3, 0, tabWidth, tabHeight);
    [self.settingsTabButton setTitle:@"Settings" forState:UIControlStateNormal];
    [self.settingsTabButton setTitleColor:[self textColor] forState:UIControlStateNormal];
    self.settingsTabButton.titleLabel.font = [UIFont systemFontOfSize:14];
    self.settingsTabButton.tag = 3;
    [self.settingsTabButton addTarget:self action:@selector(tabButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.settingsTabButton];
}

- (void)setupEditorView {
    // Editor view container
    self.editorView = [[UIView alloc] initWithFrame:CGRectMake(0, 36, self.mainView.frame.size.width, self.mainView.frame.size.height - 36)];
    [self.mainView addSubview:self.editorView];
    
    // Script text view
    self.scriptTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 10, self.editorView.frame.size.width - 20, self.editorView.frame.size.height - 60)];
    self.scriptTextView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
    self.scriptTextView.textColor = [UIColor whiteColor];
    self.scriptTextView.font = [UIFont fontWithName:@"Menlo" size:16];
    self.scriptTextView.text = self.currentScript;
    self.scriptTextView.autocorrectionType = UITextAutocorrectionTypeNo;
    self.scriptTextView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.scriptTextView.spellCheckingType = UITextSpellCheckingTypeNo;
    self.scriptTextView.delegate = self;
    [self applyCornerRadius:6.0 toView:self.scriptTextView];
    [self.editorView addSubview:self.scriptTextView];
    
    // Button container
    UIView *buttonContainer = [[UIView alloc] initWithFrame:CGRectMake(10, self.editorView.frame.size.height - 40, self.editorView.frame.size.width - 20, 40)];
    [self.editorView addSubview:buttonContainer];
    
    // Execute button
    self.executeButton = [self createStyledButton:@"Execute" color:[UIColor colorWithRed:0.2 green:0.7 blue:0.2 alpha:1.0]];
    self.executeButton.frame = CGRectMake(0, 0, 100, 36);
    [self.executeButton addTarget:self action:@selector(executeScript) forControlEvents:UIControlEventTouchUpInside];
    [buttonContainer addSubview:self.executeButton];
    
    // Clear button
    self.clearButton = [self createStyledButton:@"Clear" color:[UIColor colorWithRed:0.7 green:0.2 blue:0.2 alpha:1.0]];
    self.clearButton.frame = CGRectMake(110, 0, 100, 36);
    [self.clearButton addTarget:self action:@selector(clearEditor) forControlEvents:UIControlEventTouchUpInside];
    [buttonContainer addSubview:self.clearButton];
    
    // Save button
    self.saveButton = [self createStyledButton:@"Save Script" color:[UIColor colorWithRed:0.2 green:0.2 blue:0.7 alpha:1.0]];
    self.saveButton.frame = CGRectMake(220, 0, 100, 36);
    [self.saveButton addTarget:self action:@selector(saveScript) forControlEvents:UIControlEventTouchUpInside];
    [buttonContainer addSubview:self.saveButton];
}

- (void)setupScriptsView {
    // Scripts view container
    self.scriptsView = [[UIView alloc] initWithFrame:CGRectMake(0, 36, self.mainView.frame.size.width, self.mainView.frame.size.height - 36)];
    self.scriptsView.hidden = YES;
    [self.mainView addSubview:self.scriptsView];
    
    // Scripts header
    UIView *scriptsHeader = [[UIView alloc] initWithFrame:CGRectMake(10, 10, self.scriptsView.frame.size.width - 20, 40)];
    [self.scriptsView addSubview:scriptsHeader];
    
    // Scripts title
    UILabel *scriptsTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 40)];
    scriptsTitle.text = @"Saved Scripts";
    scriptsTitle.textColor = [self textColor];
    scriptsTitle.font = [UIFont boldSystemFontOfSize:16];
    [scriptsHeader addSubview:scriptsTitle];
    
    // Search field
    self.searchField = [[UITextField alloc] initWithFrame:CGRectMake(scriptsHeader.frame.size.width - 200, 5, 200, 30)];
    self.searchField.placeholder = @"Search scripts...";
    self.searchField.backgroundColor = [self lightBackgroundColor];
    self.searchField.textColor = [self textColor];
    self.searchField.font = [UIFont systemFontOfSize:14];
    self.searchField.borderStyle = UITextBorderStyleRoundedRect;
    self.searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [self applyCornerRadius:6.0 toView:self.searchField];
    [scriptsHeader addSubview:self.searchField];
    
    // Scripts table view
    self.scriptsTableView = [[UITableView alloc] initWithFrame:CGRectMake(10, 60, self.scriptsView.frame.size.width - 20, self.scriptsView.frame.size.height - 70) style:UITableViewStylePlain];
    self.scriptsTableView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
    self.scriptsTableView.delegate = self;
    self.scriptsTableView.dataSource = self;
    self.scriptsTableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.scriptsTableView.separatorColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
    [self applyCornerRadius:6.0 toView:self.scriptsTableView];
    [self.scriptsView addSubview:self.scriptsTableView];
    
    // Register cell class
    [self.scriptsTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ScriptCell"];
}

- (void)setupConsoleView {
    // Console view container
    self.consoleView = [[UIView alloc] initWithFrame:CGRectMake(0, 36, self.mainView.frame.size.width, self.mainView.frame.size.height - 36)];
    self.consoleView.hidden = YES;
    [self.mainView addSubview:self.consoleView];
    
    // Console header
    UIView *consoleHeader = [[UIView alloc] initWithFrame:CGRectMake(10, 10, self.consoleView.frame.size.width - 20, 40)];
    [self.consoleView addSubview:consoleHeader];
    
    // Console title
    UILabel *consoleTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 40)];
    consoleTitle.text = @"Execution Console";
    consoleTitle.textColor = [self textColor];
    consoleTitle.font = [UIFont boldSystemFontOfSize:16];
    [consoleHeader addSubview:consoleTitle];
    
    // Clear console button
    self.clearConsoleButton = [self createStyledButton:@"Clear Log" color:[UIColor colorWithRed:0.7 green:0.2 blue:0.2 alpha:1.0]];
    self.clearConsoleButton.frame = CGRectMake(consoleHeader.frame.size.width - 100, 5, 100, 30);
    [self.clearConsoleButton addTarget:self action:@selector(clearConsole) forControlEvents:UIControlEventTouchUpInside];
    [consoleHeader addSubview:self.clearConsoleButton];
    
    // Console text view
    self.consoleTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 60, self.consoleView.frame.size.width - 20, self.consoleView.frame.size.height - 70)];
    self.consoleTextView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
    self.consoleTextView.textColor = [UIColor whiteColor];
    self.consoleTextView.font = [UIFont fontWithName:@"Menlo" size:14];
    self.consoleTextView.text = self.consoleText;
    self.consoleTextView.editable = NO;
    [self applyCornerRadius:6.0 toView:self.consoleTextView];
    [self.consoleView addSubview:self.consoleTextView];
}

- (void)setupSettingsView {
    // Settings view container
    self.settingsView = [[UIView alloc] initWithFrame:CGRectMake(0, 36, self.mainView.frame.size.width, self.mainView.frame.size.height - 36)];
    self.settingsView.hidden = YES;
    [self.mainView addSubview:self.settingsView];
    
    // Settings header
    UIView *settingsHeader = [[UIView alloc] initWithFrame:CGRectMake(10, 10, self.settingsView.frame.size.width - 20, 40)];
    [self.settingsView addSubview:settingsHeader];
    
    // Settings title
    UILabel *settingsTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 40)];
    settingsTitle.text = @"Settings";
    settingsTitle.textColor = [self textColor];
    settingsTitle.font = [UIFont boldSystemFontOfSize:16];
    [settingsHeader addSubview:settingsTitle];
    
    // Settings table view
    self.settingsTableView = [[UITableView alloc] initWithFrame:CGRectMake(10, 60, self.settingsView.frame.size.width - 20, self.settingsView.frame.size.height - 70) style:UITableViewStyleGrouped];
    self.settingsTableView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
    self.settingsTableView.delegate = self;
    self.settingsTableView.dataSource = self;
    [self applyCornerRadius:6.0 toView:self.settingsTableView];
    [self.settingsView addSubview:self.settingsTableView];
    
    // Register cell class
    [self.settingsTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"SettingCell"];
}

- (void)setupFloatingButton {
    // Floating button
    self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingButton.frame = CGRectMake(UIScreen.mainScreen.bounds.size.width - 70, UIScreen.mainScreen.bounds.size.height - 150, 60, 60);
    self.floatingButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.9 alpha:0.9];
    self.floatingButton.layer.cornerRadius = 30;
    self.floatingButton.clipsToBounds = YES;
    self.floatingButton.layer.shadowColor = [UIColor blackColor].CGColor;
    self.floatingButton.layer.shadowOffset = CGSizeMake(0, 3);
    self.floatingButton.layer.shadowOpacity = 0.5;
    self.floatingButton.layer.shadowRadius = 5.0;
    [self.floatingButton setImage:[UIImage systemImageNamed:@"bolt.fill"] forState:UIControlStateNormal];
    self.floatingButton.tintColor = [UIColor whiteColor];
    [self.floatingButton addTarget:self action:@selector(floatingButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    
    // Add drop shadow
    self.floatingButton.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.floatingButton.bounds cornerRadius:30].CGPath;
    
    // Add to view
    [self.view addSubview:self.floatingButton];
    
    // Add pan gesture for dragging the floating button
    UIPanGestureRecognizer *buttonPanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleButtonPan:)];
    [self.floatingButton addGestureRecognizer:buttonPanGesture];
}

#pragma mark - Action methods

- (void)executeScript {
    NSString *script = self.scriptTextView.text;
    if (script.length == 0) {
        [self appendToConsole:@"Error: Cannot execute empty script\n"];
        return;
    }
    
    if (self.executeCallback) {
        BOOL success = self.executeCallback(script);
        if (success) {
            [self appendToConsole:@"Script executed successfully\n"];
        } else {
            [self appendToConsole:@"Error executing script\n"];
        }
    } else {
        [self appendToConsole:@"Error: Execute callback not set\n"];
    }
}

- (void)clearEditor {
    self.scriptTextView.text = @"";
    self.currentScript = @"";
}

- (void)saveScript {
    NSString *script = self.scriptTextView.text;
    if (script.length == 0) {
        [self appendToConsole:@"Error: Cannot save empty script\n"];
        return;
    }
    
    // Show save dialog
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Save Script"
                                                                             message:@"Enter a name for this script:"
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Script name";
    }];
    
    UIAlertAction *saveAction = [UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *textField = alertController.textFields.firstObject;
        NSString *scriptName = textField.text;
        
        if (scriptName.length == 0) {
            scriptName = [NSString stringWithFormat:@"Script_%@", [[NSUUID UUID] UUIDString]];
        }
        
        if (self.saveScriptCallback) {
            NSDictionary *scriptInfo = @{
                @"name": scriptName,
                @"content": script,
                @"timestamp": @((NSInteger)[[NSDate date] timeIntervalSince1970])
            };
            
            BOOL success = self.saveScriptCallback(scriptInfo);
            if (success) {
                [self appendToConsole:[NSString stringWithFormat:@"Script saved: %@\n", scriptName]];
                [self loadScriptsList];
            } else {
                [self appendToConsole:@"Error saving script\n"];
            }
        } else {
            [self appendToConsole:@"Error: Save callback not set\n"];
        }
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    
    [alertController addAction:saveAction];
    [alertController addAction:cancelAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)closeUI {
    self.mainView.hidden = YES;
    self.isVisible = NO;
    [self saveUIState];
}

- (void)minimizeUI {
    self.mainView.hidden = YES;
    self.isVisible = NO;
    [self saveUIState];
}

- (void)toggleUI {
    self.isVisible = !self.isVisible;
    self.mainView.hidden = !self.isVisible;
    
    if (self.isVisible) {
        // Bring to front
        [self.view bringSubviewToFront:self.mainView];
    }
    
    [self saveUIState];
}

- (void)floatingButtonPressed {
    [self toggleUI];
}

- (void)clearConsole {
    self.consoleTextView.text = @"-- Console cleared\n";
    self.consoleText = self.consoleTextView.text;
}

- (void)loadScriptsList {
    if (self.loadScriptsCallback) {
        NSArray *scripts = self.loadScriptsCallback();
        self.savedScripts = [NSMutableArray arrayWithArray:scripts];
        [self.scriptsTableView reloadData];
    }
}

#pragma mark - Tab Management

- (void)switchToTab:(int)tabIndex {
    self.currentTab = tabIndex;
    
    // Hide all tabs
    self.editorView.hidden = YES;
    self.scriptsView.hidden = YES;
    self.consoleView.hidden = YES;
    self.settingsView.hidden = YES;
    
    // Reset tab button colors
    [self.editorTabButton setTitleColor:[self textColor] forState:UIControlStateNormal];
    [self.scriptsTabButton setTitleColor:[self textColor] forState:UIControlStateNormal];
    [self.consoleTabButton setTitleColor:[self textColor] forState:UIControlStateNormal];
    [self.settingsTabButton setTitleColor:[self textColor] forState:UIControlStateNormal];
    
    // Show selected tab
    switch (tabIndex) {
        case 0: // Editor
            self.editorView.hidden = NO;
            [self.editorTabButton setTitleColor:[UIColor colorWithRed:0.4 green:0.8 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
            break;
        case 1: // Scripts
            self.scriptsView.hidden = NO;
            [self.scriptsTabButton setTitleColor:[UIColor colorWithRed:0.4 green:0.8 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
            [self loadScriptsList];
            break;
        case 2: // Console
            self.consoleView.hidden = NO;
            [self.consoleTabButton setTitleColor:[UIColor colorWithRed:0.4 green:0.8 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
            break;
        case 3: // Settings
            self.settingsView.hidden = NO;
            [self.settingsTabButton setTitleColor:[UIColor colorWithRed:0.4 green:0.8 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
            break;
    }
    
    [self saveUIState];
}

- (void)tabButtonPressed:(UIButton *)sender {
    [self switchToTab:(int)sender.tag];
}

#pragma mark - Helper Methods

- (UIColor *)darkBackgroundColor {
    return [UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:1.0];
}

- (UIColor *)lightBackgroundColor {
    return [UIColor colorWithRed:0.16 green:0.16 blue:0.16 alpha:1.0];
}

- (UIColor *)accentColor {
    return [UIColor colorWithRed:0.4 green:0.6 blue:1.0 alpha:1.0];
}

- (UIColor *)buttonColor {
    return [UIColor colorWithRed:0.2 green:0.2 blue:0.7 alpha:1.0];
}

- (UIColor *)textColor {
    return [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
}

- (void)appendToConsole:(NSString *)text {
    self.consoleText = [self.consoleText stringByAppendingString:text];
    self.consoleTextView.text = self.consoleText;
    
    // Scroll to bottom
    if (self.consoleTextView.text.length > 0) {
        NSRange range = NSMakeRange(self.consoleTextView.text.length - 1, 1);
        [self.consoleTextView scrollRangeToVisible:range];
    }
}

- (void)saveUIState {
    // Save UI state to UserDefaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:self.isVisible forKey:@"UIController_IsVisible"];
    [defaults setInteger:self.currentTab forKey:@"UIController_CurrentTab"];
    [defaults setFloat:self.opacity forKey:@"UIController_Opacity"];
    [defaults setBool:self.isDraggable forKey:@"UIController_IsDraggable"];
    [defaults setBool:self.buttonVisible forKey:@"UIController_ButtonVisible"];
    
    // Save mainView position
    [defaults setFloat:self.mainView.center.x forKey:@"UIController_CenterX"];
    [defaults setFloat:self.mainView.center.y forKey:@"UIController_CenterY"];
    
    // Save button position
    [defaults setFloat:self.floatingButton.center.x forKey:@"UIController_ButtonCenterX"];
    [defaults setFloat:self.floatingButton.center.y forKey:@"UIController_ButtonCenterY"];
    
    [defaults synchronize];
}

- (void)loadUIState {
    // Load UI state from UserDefaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Load mainView position if saved
    if ([defaults objectForKey:@"UIController_CenterX"] != nil && [defaults objectForKey:@"UIController_CenterY"] != nil) {
        float centerX = [defaults floatForKey:@"UIController_CenterX"];
        float centerY = [defaults floatForKey:@"UIController_CenterY"];
        self.mainView.center = CGPointMake(centerX, centerY);
    }
    
    // Load button position if saved
    if ([defaults objectForKey:@"UIController_ButtonCenterX"] != nil && [defaults objectForKey:@"UIController_ButtonCenterY"] != nil) {
        float buttonCenterX = [defaults floatForKey:@"UIController_ButtonCenterX"];
        float buttonCenterY = [defaults floatForKey:@"UIController_ButtonCenterY"];
        self.floatingButton.center = CGPointMake(buttonCenterX, buttonCenterY);
    }
    
    // Load opacity if saved
    if ([defaults objectForKey:@"UIController_Opacity"] != nil) {
        self.opacity = [defaults floatForKey:@"UIController_Opacity"];
        self.mainView.alpha = self.opacity;
    }
    
    // Load current tab if saved
    if ([defaults objectForKey:@"UIController_CurrentTab"] != nil) {
        int savedTab = (int)[defaults integerForKey:@"UIController_CurrentTab"];
        [self switchToTab:savedTab];
    }
    
    // Load button visibility if saved
    if ([defaults objectForKey:@"UIController_ButtonVisible"] != nil) {
        self.buttonVisible = [defaults boolForKey:@"UIController_ButtonVisible"];
        self.floatingButton.hidden = !self.buttonVisible;
    }
    
    // Load draggable state if saved
    if ([defaults objectForKey:@"UIController_IsDraggable"] != nil) {
        self.isDraggable = [defaults boolForKey:@"UIController_IsDraggable"];
        self.panGesture.enabled = self.isDraggable;
    }
}

- (void)applyCornerRadius:(float)radius toView:(UIView *)view {
    view.layer.cornerRadius = radius;
    view.clipsToBounds = YES;
}

- (UIButton *)createStyledButton:(NSString *)title color:(UIColor *)color {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.backgroundColor = color;
    button.layer.cornerRadius = 6.0;
    button.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    return button;
}

#pragma mark - Gesture Recognizers

- (void)handlePan:(UIPanGestureRecognizer *)recognizer {
    if (!self.isDraggable) return;
    
    CGPoint translation = [recognizer translationInView:self.view];
    
    recognizer.view.center = CGPointMake(recognizer.view.center.x + translation.x,
                                         recognizer.view.center.y + translation.y);
    
    [recognizer setTranslation:CGPointZero inView:self.view];
    
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        [self saveUIState];
    }
}

- (void)handleButtonPan:(UIPanGestureRecognizer *)recognizer {
    CGPoint translation = [recognizer translationInView:self.view];
    
    recognizer.view.center = CGPointMake(recognizer.view.center.x + translation.x,
                                         recognizer.view.center.y + translation.y);
    
    [recognizer setTranslation:CGPointZero inView:self.view];
    
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        // Ensure the button stays within screen bounds
        CGFloat buttonRadius = recognizer.view.frame.size.width / 2;
        CGFloat minX = buttonRadius;
        CGFloat maxX = self.view.bounds.size.width - buttonRadius;
        CGFloat minY = buttonRadius + [UIApplication sharedApplication].statusBarFrame.size.height;
        CGFloat maxY = self.view.bounds.size.height - buttonRadius;
        
        CGPoint buttonCenter = recognizer.view.center;
        buttonCenter.x = MAX(minX, MIN(buttonCenter.x, maxX));
        buttonCenter.y = MAX(minY, MIN(buttonCenter.y, maxY));
        
        [UIView animateWithDuration:0.3 animations:^{
            recognizer.view.center = buttonCenter;
        }];
        
        [self saveUIState];
    }
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    if (textView == self.scriptTextView) {
        self.currentScript = textView.text;
    }
}

#pragma mark - UITableViewDelegate & UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.scriptsTableView) {
        return self.savedScripts.count;
    } else if (tableView == self.settingsTableView) {
        return 3; // Number of settings options
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.scriptsTableView) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ScriptCell" forIndexPath:indexPath];
        cell.backgroundColor = [self lightBackgroundColor];
        cell.textLabel.textColor = [self textColor];
        
        if (indexPath.row < self.savedScripts.count) {
            NSDictionary *script = self.savedScripts[indexPath.row];
            cell.textLabel.text = script[@"name"];
        }
        
        return cell;
    } else if (tableView == self.settingsTableView) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SettingCell" forIndexPath:indexPath];
        cell.backgroundColor = [self lightBackgroundColor];
        cell.textLabel.textColor = [self textColor];
        
        UISwitch *toggle = [[UISwitch alloc] init];
        [toggle addTarget:self action:@selector(settingSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        toggle.tag = indexPath.row;
        cell.accessoryView = toggle;
        
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"Allow Dragging UI";
                ((UISwitch *)cell.accessoryView).on = self.isDraggable;
                break;
            case 1:
                cell.textLabel.text = @"Show Floating Button";
                ((UISwitch *)cell.accessoryView).on = self.buttonVisible;
                break;
            case 2:
                cell.textLabel.text = @"Auto Execute on Load";
                ((UISwitch *)cell.accessoryView).on = [[NSUserDefaults standardUserDefaults] boolForKey:@"AutoExecute"];
                break;
        }
        
        return cell;
    }
    
    return [[UITableViewCell alloc] init];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (tableView == self.scriptsTableView) {
        NSDictionary *script = self.savedScripts[indexPath.row];
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:script[@"name"]
                                                                                 message:@"What would you like to do with this script?"
                                                                          preferredStyle:UIAlertControllerStyleActionSheet];
        
        UIAlertAction *loadAction = [UIAlertAction actionWithTitle:@"Load to Editor" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.scriptTextView.text = script[@"content"];
            self.currentScript = script[@"content"];
            [self switchToTab:0]; // Switch to editor tab
        }];
        
        UIAlertAction *executeAction = [UIAlertAction actionWithTitle:@"Execute" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            if (self.executeCallback) {
                BOOL success = self.executeCallback(script[@"content"]);
                if (success) {
                    [self appendToConsole:[NSString stringWithFormat:@"Script '%@' executed successfully\n", script[@"name"]]];
                } else {
                    [self appendToConsole:[NSString stringWithFormat:@"Error executing script '%@'\n", script[@"name"]]];
                }
            } else {
                [self appendToConsole:@"Error: Execute callback not set\n"];
            }
        }];
        
        UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            NSString *name = script[@"name"] ?: @"";
            BOOL ok = YES;
            if (self.deleteScriptCallback) {
                ok = self.deleteScriptCallback(name);
            }
            if (ok) {
                [self.savedScripts removeObjectAtIndex:indexPath.row];
                [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                [self appendToConsole:[NSString stringWithFormat:@"Script '%@' deleted\n", name]];
            } else {
                [self appendToConsole:[NSString stringWithFormat:@"Failed to delete script '%@'\n", name]];
            }
        }];
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
        
        [alertController addAction:loadAction];
        [alertController addAction:executeAction];
        [alertController addAction:deleteAction];
        [alertController addAction:cancelAction];
        
        // For iPad
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            alertController.popoverPresentationController.sourceView = tableView;
            alertController.popoverPresentationController.sourceRect = [tableView rectForRowAtIndexPath:indexPath];
        }
        
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

#pragma mark - Settings

- (void)settingSwitchChanged:(UISwitch *)sender {
    switch (sender.tag) {
        case 0: // Allow Dragging UI
            self.isDraggable = sender.isOn;
            self.panGesture.enabled = self.isDraggable;
            break;
        case 1: // Show Floating Button
            self.buttonVisible = sender.isOn;
            self.floatingButton.hidden = !self.buttonVisible;
            break;
        case 2: // Auto Execute on Load
            [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:@"AutoExecute"];
            break;
    }
    
    [self saveUIState];
}

@end

#endif

namespace iOS {
    // Implement UI controller using C++ facade to Objective-C implementation
    
    // Initialize the UI controller
    bool UIController::Initialize() {
        if (!m_uiView) {
            try {
                // Create UI controller
                UIControllerImpl *controller = [[UIControllerImpl alloc] init];
                
                // Store the Objective-C controller in our C++ class
                m_uiView = (__bridge_retained void *)controller;
                
                // Set up floating button
                m_floatingButton = std::make_unique<FloatingButtonController>();
                
                std::cout << "UIController: Successfully initialized" << std::endl;
                
                return true;
            } catch (const std::exception& e) {
                std::cerr << "UIController: Exception during initialization: " << e.what() << std::endl;
                return false;
            }
        }
        
        return m_uiView != nullptr;
    }
    
    // Show the main interface
    void UIController::Show() {
        if (m_uiView) {
            UIControllerImpl *controller = (__bridge UIControllerImpl *)m_uiView;
            dispatch_async(dispatch_get_main_queue(), ^{
                controller.mainView.hidden = NO;
                controller.isVisible = YES;
                [controller saveUIState];
            });
            m_isVisible = true;
        }
    }
    
    // Hide the interface
    void UIController::Hide() {
        if (m_uiView) {
            UIControllerImpl *controller = (__bridge UIControllerImpl *)m_uiView;
            dispatch_async(dispatch_get_main_queue(), ^{
                controller.mainView.hidden = YES;
                controller.isVisible = NO;
                [controller saveUIState];
            });
            m_isVisible = false;
        }
    }
    
    // Toggle UI visibility
    bool UIController::Toggle() {
        if (m_uiView) {
            UIControllerImpl *controller = (__bridge UIControllerImpl *)m_uiView;
            dispatch_async(dispatch_get_main_queue(), ^{
                [controller toggleUI];
            });
            m_isVisible = !m_isVisible;
            return m_isVisible;
        }
        return false;
    }
    
    // Check if UI is visible
    bool UIController::IsVisible() const {
        return m_isVisible;
    }
    
    // Switch to a specific tab
    void UIController::SwitchTab(TabType tab) {
        if (m_uiView) {
            UIControllerImpl *controller = (__bridge UIControllerImpl *)m_uiView;
            dispatch_async(dispatch_get_main_queue(), ^{
                [controller switchToTab:(int)tab];
            });
            m_currentTab = tab;
        }
    }
    
    // Get current tab
    UIController::TabType UIController::GetCurrentTab() const {
        return m_currentTab;
    }
    
    // Set UI opacity
    void UIController::SetOpacity(float opacity) {
        if (m_uiView) {
            UIControllerImpl *controller = (__bridge UIControllerImpl *)m_uiView;
            dispatch_async(dispatch_get_main_queue(), ^{
                controller.opacity = opacity;
                controller.mainView.alpha = opacity;
                [controller saveUIState];
            });
            m_opacity = opacity;
        }
    }
    
    // Get UI opacity
    float UIController::GetOpacity() const {
        return m_opacity;
    }
    
    // Enable/disable UI dragging
    void UIController::SetDraggable(bool enabled) {
        if (m_uiView) {
            UIControllerImpl *controller = (__bridge UIControllerImpl *)m_uiView;
            dispatch_async(dispatch_get_main_queue(), ^{
                controller.isDraggable = enabled;
                controller.panGesture.enabled = enabled;
                [controller saveUIState];
            });
            m_isDraggable = enabled;
        }
    }
    
    // Check if UI is draggable
    bool UIController::IsDraggable() const {
        return m_isDraggable;
    }
    
    // Set script content in editor
    void UIController::SetScriptContent(const std::string& script) {
        if (m_uiView) {
            UIControllerImpl *controller = (__bridge UIControllerImpl *)m_uiView;
            NSString *nsScript = [NSString stringWithUTF8String:script.c_str()];
            dispatch_async(dispatch_get_main_queue(), ^{
                controller.scriptTextView.text = nsScript;
                controller.currentScript = nsScript;
            });
            m_currentScript = script;
        }
    }
    
    // Get script content from editor
    std::string UIController::GetScriptContent() const {
        return m_currentScript;
    }
    
    // Execute current script in editor
    bool UIController::ExecuteCurrentScript() {
        if (m_uiView) {
            UIControllerImpl *controller = (__bridge UIControllerImpl *)m_uiView;
            dispatch_async(dispatch_get_main_queue(), ^{
                [controller executeScript];
            });
            return true;
        }
        return false;
    }
    
    // Save current script in editor
    bool UIController::SaveCurrentScript(const std::string& name) {
        if (m_uiView) {
            UIControllerImpl *controller = (__bridge UIControllerImpl *)m_uiView;
            NSString *nsName = [NSString stringWithUTF8String:name.c_str()];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (name.empty()) {
                    [controller saveScript];
                } else {
                    // Create script info
                    NSDictionary *scriptInfo = @{
                        @"name": nsName,
                        @"content": controller.scriptTextView.text,
                        @"timestamp": @((NSInteger)[[NSDate date] timeIntervalSince1970])
                    };
                    
                    if (controller.saveScriptCallback) {
                        BOOL success = controller.saveScriptCallback(scriptInfo);
                        if (success) {
                            [controller appendToConsole:[NSString stringWithFormat:@"Script saved: %@\n", nsName]];
                            [controller loadScriptsList];
                        } else {
                            [controller appendToConsole:@"Error saving script\n"];
                        }
                    }
                }
            });
            return true;
        }
        return false;
    }
    
    // Load a script into the editor
    bool UIController::LoadScript(const ScriptInfo& scriptInfo) {
        if (m_uiView) {
            UIControllerImpl *controller = (__bridge UIControllerImpl *)m_uiView;
            NSString *nsName = [NSString stringWithUTF8String:scriptInfo.m_name.c_str()];
            NSString *nsContent = [NSString stringWithUTF8String:scriptInfo.m_content.c_str()];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                controller.scriptTextView.text = nsContent;
                controller.currentScript = nsContent;
                [controller switchToTab:0]; // Switch to editor tab
                [controller appendToConsole:[NSString stringWithFormat:@"Loaded script: %@\n", nsName]];
            });
            m_currentScript = scriptInfo.m_content;
            return true;
        }
        return false;
    }
    
    // Delete a saved script
    bool UIController::DeleteScript(const std::string& name) {
        if (m_uiView) {
            UIControllerImpl *controller = (__bridge UIControllerImpl *)m_uiView;
            NSString *nsName = [NSString stringWithUTF8String:name.c_str()];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                // Find the script in the saved scripts array
                for (int i = 0; i < controller.savedScripts.count; i++) {
                    NSDictionary *script = controller.savedScripts[i];
                    if ([script[@"name"] isEqualToString:nsName]) {
                        [controller.savedScripts removeObjectAtIndex:i];
                        [controller.scriptsTableView reloadData];
                        [controller appendToConsole:[NSString stringWithFormat:@"Script deleted: %@\n", nsName]];
                        break;
                    }
                }
            });
            return true;
        }
        return false;
    }
    
    // Clear the console
    void UIController::ClearConsole() {
        if (m_uiView) {
            UIControllerImpl *controller = (__bridge UIControllerImpl *)m_uiView;
            dispatch_async(dispatch_get_main_queue(), ^{
                [controller clearConsole];
            });
            m_consoleText = "-- Console cleared\n";
        }
    }
    
    // Get console text
    std::string UIController::GetConsoleText() const {
        return m_consoleText;
    }
    
    // Set execute callback
    void UIController::SetExecuteCallback(ExecuteCallback callback) {
        if (m_uiView && callback) {
            m_executeCallback = callback;
            
            UIControllerImpl *controller = (__bridge UIControllerImpl *)m_uiView;
            
            // Create an Objective-C block that calls our C++ callback
            controller.executeCallback = ^BOOL(NSString *script) {
                std::string scriptStr = [script UTF8String];
                return m_executeCallback(scriptStr);
            };
        }
    }
    
    // Set save script callback
    void UIController::SetSaveScriptCallback(SaveScriptCallback callback) {
        if (m_uiView && callback) {
            m_saveScriptCallback = callback;
            
            UIControllerImpl *controller = (__bridge UIControllerImpl *)m_uiView;
            
            // Create an Objective-C block that calls our C++ callback
            controller.saveScriptCallback = ^BOOL(NSDictionary *scriptDict) {
                ScriptInfo scriptInfo;
                scriptInfo.m_name = [scriptDict[@"name"] UTF8String];
                scriptInfo.m_content = [scriptDict[@"content"] UTF8String];
                scriptInfo.m_timestamp = [scriptDict[@"timestamp"] longLongValue];
                
                return m_saveScriptCallback(scriptInfo);
            };
        }
    }
    
    // Set load scripts callback
    void UIController::SetLoadScriptsCallback(LoadScriptsCallback callback) {
        if (m_uiView && callback) {
            m_loadScriptsCallback = callback;
            
            UIControllerImpl *controller = (__bridge UIControllerImpl *)m_uiView;
            
            // Create an Objective-C block that calls our C++ callback
            controller.loadScriptsCallback = ^NSArray *() {
                std::vector<ScriptInfo> scripts = m_loadScriptsCallback();
                NSMutableArray *nsScripts = [NSMutableArray array];
                
                for (const auto& script : scripts) {
                    [nsScripts addObject:@{
                        @"name": [NSString stringWithUTF8String:script.m_name.c_str()],
                        @"content": [NSString stringWithUTF8String:script.m_content.c_str()],
                        @"timestamp": @(script.m_timestamp)
                    }];
                }
                
                return nsScripts;
            };
            
            // Load scripts list
            dispatch_async(dispatch_get_main_queue(), ^{
                [controller loadScriptsList];
            });
        }
    }
    
    // Check if button is visible
    bool UIController::IsButtonVisible() const {
        return m_floatingButton ? m_floatingButton->IsVisible() : false;
    }
    
    // Show/hide floating button
    void UIController::SetButtonVisible(bool visible) {
        if (m_uiView) {
            UIControllerImpl *controller = (__bridge UIControllerImpl *)m_uiView;
            dispatch_async(dispatch_get_main_queue(), ^{
                controller.buttonVisible = visible;
                controller.floatingButton.hidden = !visible;
                [controller saveUIState];
            });
            
            if (m_floatingButton) {
                m_floatingButton->SetVisible(visible);
            }
        }
    }
    
    // Basic constructor
    UIController::UIController() 
        : m_uiView(nullptr),
          m_isVisible(false),
          m_currentTab(TabType::Editor),
          m_opacity(1.0f),
          m_isDraggable(true),
          m_currentScript("-- Welcome to Roblox Executor\n-- Enter your script here"),
          m_consoleText("-- Console output will appear here\n") {
    }
    
    // Basic destructor
    UIController::~UIController() {
        if (m_uiView) {
            // Release the retained Objective-C object
            UIControllerImpl *controller = (__bridge_transfer UIControllerImpl *)m_uiView;
            m_uiView = nullptr;
        }
    }
}

// Implementation of GetMainViewController is in UIController.h as inline method
// No implementation needed here
