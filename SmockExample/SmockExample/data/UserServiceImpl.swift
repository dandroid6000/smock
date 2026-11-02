//
//  UserServiceImpl.swift
//  SmockExample
//
//  Created by Dan Kane on 11/2/26.
//

import Foundation

class UserServiceImpl: UserService {
    static let usersUrl = "https://jsonplaceholder.typicode.com/users"
    private lazy var jsonDecoder = JSONDecoder()
    private var updateCallbacks: [@Sendable ([User]) -> Void] = []

    private(set) var cachedUserCount: Int = 0

    var isOfflineModeEnabled: Bool = false

    func getUser(id: Int) async throws -> User? {
        guard let url = URL(string: "\(Self.usersUrl)/\(id)") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        // JSONPlaceholder returns 404 for missing IDs
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
            return nil
        }

        return try JSONDecoder().decode(User.self, from: data)
    }
    
    func updateUser(id: Int, name: String) async throws -> Bool {
        guard let url = URL(string: "\(Self.usersUrl)/\(id)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ["name": name]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)

        // JSONPlaceholder returns 200 OK for successful PATCH requests
        return (response as? HTTPURLResponse)?.statusCode == 200
    }
    
    func deleteUser(_ id: Int) async throws {
        guard let url = URL(string: "https://jsonplaceholder.typicode.com/users/\(id)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    func subscribeToUpdates(onUpdate: @escaping @Sendable ([User]) -> Void) {
        updateCallbacks.append(onUpdate)
    }

    func fetchUsers() async throws -> [User] {
        guard let url = URL(string: Self.usersUrl) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let users = try jsonDecoder.decode([User].self, from: data)

        cachedUserCount = users.count
        updateCallbacks.forEach { callback in
            callback(users)
        }

        return users
    }
}
