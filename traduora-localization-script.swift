#!/usr/bin/env swift

// Traduora Localization Script
// A Swift script to automatically download and update localization files from Traduora
// 
// Repository: https://github.com/cayde-6/traduora-localization-script
// License: MIT
// Author: Maksim Egorov
// Version: 1.0.0

import Foundation

// MARK: - Models
struct AuthRequest: Codable {
    let grant_type: String
    let username: String
    let password: String
    
    init(username: String, password: String) {
        self.grant_type = "password"
        self.username = username
        self.password = password
    }
}

struct AuthResponse: Codable {
    let access_token: String
}

struct Locale: Codable {
    let code: String
    let language: String
}

struct ProjectLocale: Codable {
    let locale: Locale
}

struct LocalesResponse: Codable {
    let data: [ProjectLocale]
}

// MARK: - Configuration
struct Config {
    let baseURL: String
    let email: String
    let password: String
    let projectId: String
    let localizationPath: String
    let targetLocales: [String]
    let format: String
}

// MARK: - TraduoraAPI
class TraduoraAPI {
    private let config: Config
    private var accessToken: String?
    
    init(config: Config) {
        self.config = config
    }
    
    func authenticate() async throws {
        let url = URL(string: "\(config.baseURL)/api/v1/auth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let authRequest = AuthRequest(username: config.email, password: config.password)
        request.httpBody = try JSONEncoder().encode(authRequest)
        
        print("🔐 Authenticating...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.authenticationFailed
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        self.accessToken = authResponse.access_token
        print("✅ Authentication successful")
    }
    
    func getAvailableLocales() async throws -> [String] {
        guard let token = accessToken else {
            throw APIError.noToken
        }
        
        let url = URL(string: "\(config.baseURL)/api/v1/projects/\(config.projectId)/translations")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
        
        let localesResponse = try JSONDecoder().decode(LocalesResponse.self, from: data)
        return localesResponse.data.map { $0.locale.code }
    }
    
    func downloadStrings(locale: String) async throws -> String {
        guard let token = accessToken else {
            throw APIError.noToken
        }
        
        var components = URLComponents(string: "\(config.baseURL)/api/v1/projects/\(config.projectId)/exports")!
        components.queryItems = [
            URLQueryItem(name: "locale", value: locale),
            URLQueryItem(name: "format", value: config.format),
            URLQueryItem(name: "untranslated", value: "false")
        ]
        
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
        
        let content = String(data: data, encoding: .utf8) ?? ""
        return content
    }
}

// MARK: - Errors
enum APIError: Error {
    case authenticationFailed
    case noToken
    case requestFailed
    case projectNotFound
    case configurationError
}

// MARK: - Helper Functions
func checkEnvironmentFile() {
    let currentDirectory = FileManager.default.currentDirectoryPath
    let envPath = "\(currentDirectory)/.env"
    
    if !FileManager.default.fileExists(atPath: envPath) {
        print("❌ .env file not found. Please create it with your Traduora credentials.")
        print("Example:")
        print("TRADUORA_BASE_URL=https://your-traduora-instance.com")
        print("TRADUORA_EMAIL=your-email@example.com")
        print("TRADUORA_PASSWORD=your-password")
        print("PROJECT_ID=your-project-id")
        print("LOCALIZATION_PATH=./path/to/localization")
        print("TARGET_LOCALES=en,es,fr")
        print("FORMAT=strings")
        exit(1)
    }
}

func loadConfig() throws -> Config {
    let currentDirectory = FileManager.default.currentDirectoryPath
    let envPath = "\(currentDirectory)/.env"
    
    guard FileManager.default.fileExists(atPath: envPath) else {
        throw APIError.configurationError
    }
    
    let envContent = try String(contentsOfFile: envPath, encoding: .utf8)
    let lines = envContent.components(separatedBy: .newlines)
    
    var envVars: [String: String] = [:]
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
            // Split only on the first = to handle values with = in them
            if let equalIndex = trimmed.firstIndex(of: "=") {
                let key = String(trimmed[..<equalIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: equalIndex)...]).trimmingCharacters(in: .whitespaces)
                
                // Remove quotes if present
                let cleanValue: String
                if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
                    cleanValue = String(value.dropFirst().dropLast())
                } else {
                    cleanValue = value
                }
                
                envVars[key] = cleanValue
            }
        }
    }
    
    guard let baseURL = envVars["TRADUORA_BASE_URL"],
          let email = envVars["TRADUORA_EMAIL"],
          let password = envVars["TRADUORA_PASSWORD"],
          let projectId = envVars["PROJECT_ID"],
          let localizationPath = envVars["LOCALIZATION_PATH"],
          let targetLocalesString = envVars["TARGET_LOCALES"] else {
        print("❌ Missing required environment variables in .env file")
        print("Required variables: TRADUORA_BASE_URL, TRADUORA_EMAIL, TRADUORA_PASSWORD, PROJECT_ID, LOCALIZATION_PATH, TARGET_LOCALES, FORMAT")
        throw APIError.configurationError
    }
    
    // Get format with default value
    let format = envVars["FORMAT"] ?? "strings"
    
    // Parse target locales (comma-separated)
    let targetLocales = targetLocalesString
        .components(separatedBy: ",")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
    
    return Config(baseURL: baseURL, email: email, password: password, projectId: projectId, localizationPath: localizationPath, targetLocales: targetLocales, format: format)
}

func createLocalizationDirectory(for locale: String, config: Config) throws {
    let localizationDir = "\(config.localizationPath)/\(locale).lproj"
    
    if !FileManager.default.fileExists(atPath: localizationDir) {
        try FileManager.default.createDirectory(atPath: localizationDir, withIntermediateDirectories: true)
        print("📁 Created directory: \(localizationDir)")
    }
}

func saveStringsFile(content: String, locale: String, config: Config) throws {
    let filePath = "\(config.localizationPath)/\(locale).lproj/Localizable.strings"
    
    try content.write(toFile: filePath, atomically: true, encoding: .utf8)
    print("💾 Saved: \(filePath)")
}

// MARK: - Main Function
func main() async {
    do {
        print("🔄 Updating localization from Traduora...")
        
        // Check if .env file exists
        checkEnvironmentFile()
        
        // Load configuration
        let config = try loadConfig()
        print("⚙️  Configuration loaded")
        
        // Initialize API client
        let api = TraduoraAPI(config: config)
        
        // Authenticate
        try await api.authenticate()
        
        print("📦 Using project ID: \(config.projectId)")
        
        // First, get available locales in the project
        print("📋 Getting available locales...")
        let availableLocaleCodes = try await api.getAvailableLocales()
        
        print("✅ Available locales in project: \(availableLocaleCodes.joined(separator: ", "))")
        
        // Find which target locales are available
        let localesToDownload = config.targetLocales.filter { availableLocaleCodes.contains($0) }
        
        if localesToDownload.isEmpty {
            print("❌ None of the target locales (\(config.targetLocales.joined(separator: ", "))) are available in the project")
            return
        }
        
        print("📥 Will download locales: \(localesToDownload.joined(separator: ", "))")
        
        // Download localization for each available locale
        for locale in localesToDownload {
            print("🌐 Processing locale: \(locale)")
            
            do {
                let stringsContent = try await api.downloadStrings(locale: locale)
                
                // Create localization directory
                try createLocalizationDirectory(for: locale, config: config)
                
                // Save strings file
                try saveStringsFile(content: stringsContent, locale: locale, config: config)
                
                print("✅ Successfully updated \(locale) localization")
            } catch {
                print("⚠️  Failed to update \(locale) localization: \(error)")
            }
        }
        
        print("🎉 Localization update completed!")
        
    } catch {
        print("❌ Error: \(error)")
        exit(1)
    }
}

// MARK: - Script Execution
await main()
