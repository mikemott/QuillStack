//
//  GitHubService.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import Foundation
import Observation

// MARK: - GitHub Models

struct GitHubRepository: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let fullName: String
    let isPrivate: Bool
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case fullName = "full_name"
        case isPrivate = "private"
    }
}

struct GitHubIssue: Codable {
    let id: Int
    let number: Int
    let title: String
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case id, number, title
        case htmlUrl = "html_url"
    }
}

struct CreateIssueRequest: Codable {
    let title: String
    let body: String
    let labels: [String]
}

// MARK: - Device Flow Models

struct DeviceCodeResponse: Codable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

struct AccessTokenResponse: Codable {
    let accessToken: String?
    let tokenType: String?
    let scope: String?
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case error
        case errorDescription = "error_description"
    }
}

// MARK: - GitHub Errors

enum GitHubError: LocalizedError {
    case notAuthenticated
    case createFailed(String)
    case rateLimited
    case authTimeout
    case authDenied
    case invalidResponse
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with GitHub. Please connect your account in Settings."
        case .createFailed(let message):
            return "Failed to create issue: \(message)"
        case .rateLimited:
            return "GitHub API rate limit exceeded. Please try again later."
        case .authTimeout:
            return "Authentication timed out. Please try again."
        case .authDenied:
            return "Authentication was denied. Please try again."
        case .invalidResponse:
            return "Invalid response from GitHub API."
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - GitHub Service

/// Service for GitHub API integration with OAuth Device Flow authentication
@MainActor @Observable
final class GitHubService {
    static let shared = GitHubService()

    // MARK: - Published State

    var isAuthenticated: Bool = false
    var repositories: [GitHubRepository] = []
    var selectedRepository: GitHubRepository?
    var isAuthenticating: Bool = false
    var authError: String?

    // Device flow state
    var deviceCode: DeviceCodeResponse?

    // MARK: - Private Properties

    /// GitHub OAuth App Client ID for QuillStack
    private let clientId = "Ov23lipjkNKzKU7pbO5t"

    private let keychain = KeychainService.shared

    private var accessToken: String? {
        keychain.retrieve(for: .gitHubAccessToken)
    }

    // MARK: - Initialization

    private init() {
        isAuthenticated = accessToken != nil
    }

    // MARK: - Authentication

    /// Initiates GitHub OAuth Device Flow
    /// Returns the device code response for UI display
    func startAuthentication() async throws -> DeviceCodeResponse {
        isAuthenticating = true
        authError = nil

        do {
            let deviceCodeResponse = try await requestDeviceCode()
            self.deviceCode = deviceCodeResponse
            return deviceCodeResponse
        } catch {
            isAuthenticating = false
            authError = error.localizedDescription
            throw error
        }
    }

    /// Polls for access token after user completes device flow
    func pollForAuthentication() async throws {
        guard let deviceCode = deviceCode else {
            throw GitHubError.invalidResponse
        }

        defer {
            isAuthenticating = false
        }

        do {
            let token = try await pollForAccessToken(deviceCode: deviceCode)
            try keychain.save(token, for: .gitHubAccessToken)
            isAuthenticated = true
            self.deviceCode = nil

            // Fetch repositories after successful auth
            try await fetchRepositories()
        } catch {
            authError = error.localizedDescription
            throw error
        }
    }

    /// Disconnects GitHub account
    func disconnect() {
        try? keychain.delete(for: .gitHubAccessToken)
        isAuthenticated = false
        repositories = []
        selectedRepository = nil
        deviceCode = nil
    }

    // MARK: - Device Flow Implementation

    private func requestDeviceCode() async throws -> DeviceCodeResponse {
        let url = URL(string: "https://github.com/login/device/code")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "client_id": clientId,
            "scope": "repo"
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GitHubError.networkError("Failed to request device code")
        }

        return try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
    }

    private func pollForAccessToken(deviceCode: DeviceCodeResponse) async throws -> String {
        let url = URL(string: "https://github.com/login/oauth/access_token")!
        let maxAttempts = deviceCode.expiresIn / deviceCode.interval

        for _ in 0..<maxAttempts {
            try await Task.sleep(nanoseconds: UInt64(deviceCode.interval) * 1_000_000_000)

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: String] = [
                "client_id": clientId,
                "device_code": deviceCode.deviceCode,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
            ]
            request.httpBody = try JSONEncoder().encode(body)

            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(AccessTokenResponse.self, from: data)

            if let token = tokenResponse.accessToken {
                return token
            }

            // Handle error states
            if let error = tokenResponse.error {
                switch error {
                case "authorization_pending":
                    // User hasn't authorized yet, keep polling
                    continue
                case "slow_down":
                    // Add extra delay
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    continue
                case "expired_token":
                    throw GitHubError.authTimeout
                case "access_denied":
                    throw GitHubError.authDenied
                default:
                    throw GitHubError.networkError(tokenResponse.errorDescription ?? error)
                }
            }
        }

        throw GitHubError.authTimeout
    }

    // MARK: - Repositories

    func fetchRepositories() async throws {
        guard let token = accessToken else {
            throw GitHubError.notAuthenticated
        }

        let url = URL(string: "https://api.github.com/user/repos?sort=updated&per_page=30")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            repositories = try JSONDecoder().decode([GitHubRepository].self, from: data)
        case 401:
            // Token expired or invalid
            disconnect()
            throw GitHubError.notAuthenticated
        case 403:
            throw GitHubError.rateLimited
        default:
            throw GitHubError.networkError("Failed to fetch repositories: \(httpResponse.statusCode)")
        }
    }

    // MARK: - Issues

    /// Creates a new GitHub issue in the specified repository
    func createIssue(
        in repo: GitHubRepository,
        title: String,
        body: String,
        labels: [String]
    ) async throws -> GitHubIssue {
        guard let token = accessToken else {
            throw GitHubError.notAuthenticated
        }

        let url = URL(string: "https://api.github.com/repos/\(repo.fullName)/issues")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = CreateIssueRequest(title: title, body: body, labels: labels)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 201:
            return try JSONDecoder().decode(GitHubIssue.self, from: data)
        case 401:
            disconnect()
            throw GitHubError.notAuthenticated
        case 403:
            throw GitHubError.rateLimited
        case 404:
            throw GitHubError.createFailed("Repository not found or you don't have permission")
        case 422:
            // Validation failed - parse error message
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorData["message"] as? String {
                throw GitHubError.createFailed(message)
            }
            throw GitHubError.createFailed("Validation failed")
        default:
            throw GitHubError.createFailed("HTTP \(httpResponse.statusCode)")
        }
    }

    // MARK: - Labels

    /// Fetches available labels for a repository
    func fetchLabels(for repo: GitHubRepository) async throws -> [String] {
        guard let token = accessToken else {
            throw GitHubError.notAuthenticated
        }

        let url = URL(string: "https://api.github.com/repos/\(repo.fullName)/labels?per_page=100")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            // Return default labels if fetch fails
            return ["enhancement", "bug", "documentation"]
        }

        struct LabelResponse: Codable {
            let name: String
        }

        let labels = try JSONDecoder().decode([LabelResponse].self, from: data)
        return labels.map { $0.name }
    }
}
