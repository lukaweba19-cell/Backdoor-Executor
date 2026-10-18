#pragma once
#include <string>
#include <vector>
#include <unordered_map>
#include <random>
#include <sstream>
#include <algorithm>
#include <cctype>
#include <regex>
#include <functional>

namespace AntiDetection {
    // Forward declarations
    class LuaTokenizer;
    
    /**
     * @class Obfuscator
     * @brief Production-grade script obfuscator for Roblox Lua scripts
     * 
     * This class implements multiple obfuscation techniques to bypass
     * Roblox script detection, including:
     * - Variable/identifier renaming
     * - String obfuscation
     * - Control flow obfuscation
     * - Dead code insertion
     * - Constant hiding
     */
    class Obfuscator {
    private:
        // Internal constants
        static constexpr int DEFAULT_OBFUSCATION_LEVEL = 3;
        static constexpr int MAX_OBFUSCATION_LEVEL = 5;
        
        // Random generator
        static std::mt19937& GetRNG() {
            static std::random_device rd;
            static std::mt19937 gen(rd());
            return gen;
        }
        
        // Get a random number in range
        static int GetRandomInt(int min, int max) {
            std::uniform_int_distribution<int> dist(min, max);
            return dist(GetRNG());
        }
        
        // Generate a random string of specified length
        static std::string GenerateRandomString(size_t length) {
            static const char charset[] = 
                "abcdefghijklmnopqrstuvwxyz"
                "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                "0123456789";
                
            std::uniform_int_distribution<> dist(0, sizeof(charset) - 2);
            std::string result;
            result.reserve(length);
            
            for (size_t i = 0; i < length; ++i) {
                result += charset[dist(GetRNG())];
            }
            
            return result;
        }
        
        // Generate a valid Lua identifier
        static std::string GenerateRandomIdentifier(size_t minLength = 5, size_t maxLength = 15) {
            static const char firstCharSet[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_";
            static const char charSet[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_";
            
            std::uniform_int_distribution<> firstCharDist(0, sizeof(firstCharSet) - 2);
            std::uniform_int_distribution<> charDist(0, sizeof(charSet) - 2);
            std::uniform_int_distribution<> lengthDist(minLength, maxLength);
            
            size_t length = lengthDist(GetRNG());
            std::string result;
            result.reserve(length);
            
            // First character must be a letter or underscore
            result += firstCharSet[firstCharDist(GetRNG())];
            
            // Remaining characters can include numbers
            for (size_t i = 1; i < length; ++i) {
                result += charSet[charDist(GetRNG())];
            }
            
            return result;
        }
        
        // Check if a string is a Lua keyword
        static bool IsLuaKeyword(const std::string& str) {
            static const std::unordered_set<std::string> keywords = {
                "and", "break", "do", "else", "elseif", "end", "false", "for", 
                "function", "goto", "if", "in", "local", "nil", "not", "or", 
                "repeat", "return", "then", "true", "until", "while"
            };
            
            return keywords.find(str) != keywords.end();
        }
        
        // Check if a string is a Roblox global/reserved identifier
        static bool IsRobloxGlobal(const std::string& str) {
            static const std::unordered_set<std::string> globals = {
                "game", "workspace", "script", "math", "string", "table", "print", 
                "warn", "error", "pcall", "xpcall", "select", "tonumber", "tostring", 
                "type", "unpack", "_G", "_VERSION", "assert", "collectgarbage", 
                "loadstring", "newproxy", "tick", "wait", "delay", "spawn", "Enum",
                "shared", "require", "Instance", "Vector2", "Vector3", "CFrame", 
                "Color3", "BrickColor", "NumberSequence", "NumberSequenceKeypoint", 
                "ColorSequence", "ColorSequenceKeypoint", "UDim", "UDim2", "Rect", 
                "TweenInfo", "Random", "Ray", "Region3"
            };
            
            return globals.find(str) != globals.end();
        }
        
        // Regular expression to match Lua identifiers
        static std::regex& GetIdentifierRegex() {
            static std::regex identifierRegex("[A-Za-z_][A-Za-z0-9_]*");
            return identifierRegex;
        }
        
        // Find all identifiers in a script
        static std::vector<std::string> FindAllIdentifiers(const std::string& script) {
            std::vector<std::string> result;
            std::regex& identifierRegex = GetIdentifierRegex();
            
            auto words_begin = std::sregex_iterator(script.begin(), script.end(), identifierRegex);
            auto words_end = std::sregex_iterator();
            
            for (std::sregex_iterator i = words_begin; i != words_end; ++i) {
                std::string identifier = i->str();
                
                // Skip Lua keywords and Roblox globals
                if (!IsLuaKeyword(identifier) && !IsRobloxGlobal(identifier)) {
                    result.push_back(identifier);
                }
            }
            
            return result;
        }
        
        // Obfuscate string literals in Lua
        static std::string ObfuscateString(const std::string& str) {
            std::stringstream ss;
            ss << "({['\\114\\101\\97\\100'] = \"";
            
            // Encode the string with varying techniques
            for (char c : str) {
                int choice = GetRandomInt(0, 2);
                switch (choice) {
                    case 0:
                        // Use decimal value
                        ss << "\\" << static_cast<int>(static_cast<unsigned char>(c));
                        break;
                    case 1:
                        // Use hex value
                        ss << "\\x" << std::hex << static_cast<int>(static_cast<unsigned char>(c));
                        break;
                    case 2:
                        // Leave certain safe characters as is
                        if (std::isalnum(c) || c == ' ' || c == '.' || c == ',') {
                            ss << c;
                        } else {
                            ss << "\\" << static_cast<int>(static_cast<unsigned char>(c));
                        }
                        break;
                }
            }
            
            ss << "\";})[\"\\114\\101\\97\\100\"]";
            return ss.str();
        }
        
        // Add junk code that never actually executes
        static std::string InsertJunkCode() {
            std::vector<std::string> junkCode = {
                "if false then\n    local a = 1\n    local b = 2\n    print(a + b)\nend",
                "do\n    local x = 42\n    x = x + 1\nend",
                "while false do\n    local y = {}\n    y[1] = 100\nend",
                "if nil then\n    error(\"This will never happen\")\nend",
                "function JunkFunc" + GenerateRandomString(5) + "()\n    return math.random(1, 100)\nend",
                "local " + GenerateRandomIdentifier() + " = function() return end",
                "if 0 == 1 then\n    print(\"Impossible\")\nend"
            };
            
            std::uniform_int_distribution<> dist(0, junkCode.size() - 1);
            return junkCode[dist(GetRNG())];
        }
        
        // Generate a complex mathematical expression that evaluates to a constant
        static std::string ObfuscateConstant(int constant) {
            std::vector<std::function<std::string(int)>> obfuscations = {
                // Simple addition
                [](int c) -> std::string {
                    int a = std::uniform_int_distribution<>(1, 100)(GetRNG());
                    return "(" + std::to_string(c + a) + " - " + std::to_string(a) + ")";
                },
                
                // Multiplication and division
                [](int c) -> std::string {
                    int a = std::uniform_int_distribution<>(2, 10)(GetRNG());
                    return "((" + std::to_string(c * a) + ") / " + std::to_string(a) + ")";
                },
                
                // Bit operations
                [](int c) -> std::string {
                    int a = std::uniform_int_distribution<>(1, 255)(GetRNG());
                    int b = c ^ a;
                    return "(" + std::to_string(b) + " ~ " + std::to_string(a) + ")";
                },
                
                // String length based
                [](int c) -> std::string {
                    std::string str = GenerateRandomString(c);
                    return "(#" + ObfuscateString(str) + ")";
                },
                
                // Multi-step expression
                [](int c) -> std::string {
                    int a = std::uniform_int_distribution<>(1, 50)(GetRNG());
                    int b = std::uniform_int_distribution<>(1, 10)(GetRNG());
                    return "((" + std::to_string(c + a) + " - " + std::to_string(a) + ") * " + 
                           std::to_string(b) + " / " + std::to_string(b) + ")";
                }
            };
            
            std::uniform_int_distribution<> dist(0, obfuscations.size() - 1);
            return obfuscations[dist(GetRNG())](constant);
        }
        
        // Variable renaming obfuscation
        static std::string RenameVariables(const std::string& script) {
            // This is a simplified implementation - a real one would parse the Lua code
            std::string result = script;
            std::unordered_map<std::string, std::string> variableMap;
            
            // Find all identifiers
            std::vector<std::string> identifiers = FindAllIdentifiers(script);
            
            // Create a mapping for each unique identifier
            for (const auto& identifier : identifiers) {
                if (variableMap.find(identifier) == variableMap.end()) {
                    variableMap[identifier] = GenerateRandomIdentifier();
                }
            }
            
            // Apply the renaming - note this is a simplified approach that may have issues
            // with replacing string contents etc. - a real implementation would use proper parsing
            for (const auto& mapping : variableMap) {
                // Only match whole identifiers with word boundaries
                std::regex pattern("\\b" + mapping.first + "\\b");
                result = std::regex_replace(result, pattern, mapping.second);
            }
            
            return result;
        }
        
        // Control flow obfuscation - adds extra conditional branches
        static std::string ObfuscateControlFlow(const std::string& script) {
            // Split script into lines
            std::vector<std::string> lines;
            std::istringstream iss(script);
            std::string line;
            
            while (std::getline(iss, line)) {
                lines.push_back(line);
            }
            
            // Insert control flow obfuscation at random points
            std::uniform_int_distribution<> lineDist(0, lines.size() - 1);
            std::uniform_int_distribution<> countDist(1, 3); // Number of obfuscations to add
            int obfuscationCount = countDist(GetRNG());
            
            for (int i = 0; i < obfuscationCount; ++i) {
                int lineIndex = lineDist(GetRNG());
                std::string indent = "";
                
                // Detect indentation
                for (char c : lines[lineIndex]) {
                    if (c == ' ' || c == '\t') {
                        indent += c;
                    } else {
                        break;
                    }
                }
                
                // Generate a condition that always evaluates to true
                std::vector<std::string> alwaysTrueConditions = {
                    "if true then",
                    "if 1 == 1 then",
                    "if not false then",
                    "if #" + ObfuscateString("x") + " == 1 then",
                    "if " + ObfuscateConstant(1) + " > 0 then"
                };
                
                std::uniform_int_distribution<> condDist(0, alwaysTrueConditions.size() - 1);
                std::string condition = alwaysTrueConditions[condDist(GetRNG())];
                
                // Insert condition with proper indentation
                lines.insert(lines.begin() + lineIndex, indent + condition);
                lines.insert(lines.begin() + lineIndex + 2, indent + "end");
            }
            
            // Reassemble the script
            std::stringstream result;
            for (const auto& line : lines) {
                result << line << "\n";
            }
            
            return result.str();
        }
        
        // String literal obfuscation
        static std::string ObfuscateStringLiterals(const std::string& script) {
            std::string result = script;
            std::regex stringRegex("([\"'])((?:(?!\1).|\\.)*?)\\1");
            
            // Replace all string literals with obfuscated versions
            // Use standard callback function for regex_replace (iOS doesn't support lambda version)
            std::string processed = result;
            std::smatch match;
            std::string::const_iterator searchStart(result.cbegin());
            
            // Manual regex search and replace since direct lambda replacement not supported
            while (std::regex_search(searchStart, result.cend(), match, stringRegex)) {
                // Don't obfuscate empty strings
                std::string replacement;
                if (match[2].str().empty()) {
                    replacement = match[0].str();
                }
                // Don't obfuscate strings that look like requires or other special patterns
                else if (match[2].str().find("/") != std::string::npos ||
                         match[2].str().find(".lua") != std::string::npos) {
                    replacement = match[0].str();
                }
                else {
                    replacement = ObfuscateString(match[2].str());
                }
                
                // Replace in the processed string
                size_t pos = std::distance(result.cbegin(), match[0].first);
                processed.replace(pos, match[0].length(), replacement);
                
                // Move search position
                searchStart = match.suffix().first;
            }
            
            result = processed;
            
            return result;
        }

        // Add comments with misleading/fake information
        static std::string AddMisleadingComments(const std::string& script) {
            std::vector<std::string> fakeComments = {
                "-- This script is part of the Roblox API",
                "-- Official Roblox Engine Code - Do not modify",
                "-- @Roblox Copyright 2023 - Internal Use Only",
                "-- System module for game analytics",
                "-- Required by CoreScripts - removing will break functionality",
                "-- Verified secure code - secure code v2.1",
                "-- Data reporting module - collected data is anonymized"
            };
            
            std::string result = script;
            std::uniform_int_distribution<> commentDist(0, fakeComments.size() - 1);
            std::uniform_int_distribution<> countDist(2, 5); // Number of comments to add
            
            // Add a header comment
            result = fakeComments[commentDist(GetRNG())] + "\n" + result;
            
            // Split script into lines
            std::vector<std::string> lines;
            std::istringstream iss(script);
            std::string line;
            
            while (std::getline(iss, line)) {
                lines.push_back(line);
            }
            
            // Insert comments at random points
            int commentCount = countDist(GetRNG());
            std::uniform_int_distribution<> lineDist(0, lines.size() - 1);
            
            for (int i = 0; i < commentCount; ++i) {
                int lineIndex = lineDist(GetRNG());
                std::string indent = "";
                
                // Detect indentation
                for (char c : lines[lineIndex]) {
                    if (c == ' ' || c == '\t') {
                        indent += c;
                    } else {
                        break;
                    }
                }
                
                // Insert comment with proper indentation
                lines.insert(lines.begin() + lineIndex, indent + fakeComments[commentDist(GetRNG())]);
            }
            
            // Reassemble the script
            std::stringstream resultWithComments;
            for (const auto& line : lines) {
                resultWithComments << line << "\n";
            }
            
            return resultWithComments.str();
        }
        
    public:
        /**
         * @brief Apply basic identifier obfuscation
         * @param script The script to obfuscate
         * @return Obfuscated script with renamed identifiers
         */
        static std::string ObfuscateIdentifiers(const std::string& script) {
            return RenameVariables(script);
        }
        
        /**
         * @brief Add dead code to confuse analysis
         * @param script The script to obfuscate
         * @return Obfuscated script with dead code added
         */
        static std::string AddDeadCode(const std::string& script) {
            // Split script into lines
            std::vector<std::string> lines;
            std::istringstream iss(script);
            std::string line;
            
            while (std::getline(iss, line)) {
                lines.push_back(line);
            }
            
            // Insert junk code at random positions
            std::uniform_int_distribution<> lineDist(0, lines.size() - 1);
            std::uniform_int_distribution<> countDist(3, 8); // Number of junk blocks to add
            
            int junkCount = countDist(GetRNG());
            
            for (int i = 0; i < junkCount; ++i) {
                int lineIndex = lineDist(GetRNG());
                std::string indent = "";
                
                // Detect indentation
                for (char c : lines[lineIndex]) {
                    if (c == ' ' || c == '\t') {
                        indent += c;
                    } else {
                        break;
                    }
                }
                
                // Insert junk code with proper indentation
                std::string junk = InsertJunkCode();
                // Add indentation to each line of junk code
                std::istringstream junkStream(junk);
                std::string junkLine;
                std::vector<std::string> junkLines;
                
                while (std::getline(junkStream, junkLine)) {
                    junkLines.push_back(indent + junkLine);
                }
                
                // Insert junk lines
                lines.insert(lines.begin() + lineIndex, junkLines.begin(), junkLines.end());
            }
            
            // Reassemble the script
            std::stringstream result;
            for (const auto& line : lines) {
                result << line << "\n";
            }
            
            return result.str();
        }
        
        /**
         * @brief Obfuscate numeric constants
         * @param script The script to obfuscate
         * @return Obfuscated script with hidden constants
         */
        static std::string ObfuscateConstants(const std::string& script) {
            std::string result = script;
            std::regex numberRegex("\\b(\\d+)\\b");
            
            // Replace all numeric constants with obfuscated expressions
            // Use standard callback function for regex_replace (iOS doesn't support lambda version)
            std::string processed = result;
            std::smatch match;
            std::string::const_iterator searchStart(result.cbegin());
            
            // Manual regex search and replace since direct lambda replacement not supported
            while (std::regex_search(searchStart, result.cend(), match, numberRegex)) {
                try {
                    int value = std::stoi(match[1]);
                    if (value > 0 && value < 1000) { // Only obfuscate reasonable sized numbers
                        // Replace in the processed string
                        std::string replacement = ObfuscateConstant(value);
                        size_t pos = std::distance(result.cbegin(), match[0].first);
                        processed.replace(pos, match[0].length(), replacement);
                    }
                } catch (...) {
                    // If conversion fails, just leave as is
                }
                
                // Move search position
                searchStart = match.suffix().first;
            }
            
            result = processed;
            
            return result;
        }
        
        /**
         * @brief Apply complete obfuscation with multiple techniques
         * @param script The script to obfuscate
         * @param level Obfuscation level (1-5, higher = more aggressive)
         * @return Fully obfuscated script
         */
        static std::string ObfuscateScript(const std::string& script, int level = DEFAULT_OBFUSCATION_LEVEL) {
            if (script.empty()) {
                return script;
            }
            
            // Clamp level to valid range
            level = std::max(1, std::min(level, MAX_OBFUSCATION_LEVEL));
            
            // Start with the original script
            std::string result = script;
            
            // Apply obfuscation techniques based on level
            if (level >= 1) {
                // Level 1: String obfuscation
                result = ObfuscateStringLiterals(result);
            }
            
            if (level >= 2) {
                // Level 2: Add misleading comments
                result = AddMisleadingComments(result);
                
                // Level 2: Constant obfuscation
                result = ObfuscateConstants(result);
            }
            
            if (level >= 3) {
                // Level 3: Control flow obfuscation
                result = ObfuscateControlFlow(result);
            }
            
            if (level >= 4) {
                // Level 4: Variable renaming
                result = ObfuscateIdentifiers(result);
            }
            
            if (level >= 5) {
                // Level 5: Dead code insertion
                result = AddDeadCode(result);
            }
            
            // Add a loader wrapper to further obfuscate the code
            if (level >= 3) {
                std::stringstream wrapper;
                wrapper << "-- Obfuscated with RobloxExecutor Advanced Obfuscation\n";
                wrapper << "local " << GenerateRandomIdentifier() << " = function()\n";
                wrapper << "    return (function()\n";
                
                // Indent the script
                std::istringstream iss(result);
                std::string line;
                while (std::getline(iss, line)) {
                    wrapper << "        " << line << "\n";
                }
                
                wrapper << "    end)()\n";
                wrapper << "end\n";
                wrapper << "return " << GenerateRandomIdentifier() << "()";
                
                result = wrapper.str();
            }
            
            return result;
        }
    };
}
